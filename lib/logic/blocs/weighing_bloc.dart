import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:signalr_core/signalr_core.dart';

import '../../data/services/config_service.dart';
import '../../data/repositories/weighing_repository.dart';
import '../../data/models/phieu_can_model.dart';

/// =======================
/// 1. EVENTS (Các sự kiện)
/// =======================
abstract class WeighingEvent {}

class InitSignalR extends WeighingEvent {}

class UpdateRealtimeData extends WeighingEvent {
  final String? weight;
  final String? plate;

  UpdateRealtimeData({this.weight, this.plate});
}

class SubmitTicket extends WeighingEvent {
  final String note;

  SubmitTicket({this.note = ""});
}

class TriggerBarrier extends WeighingEvent {}

class SyncOffline extends WeighingEvent {}

/// =======================
/// 2. STATE (Trạng thái UI)
/// =======================
class WeighingState {
  final String weight;
  final String plate;
  final String message;
  final bool isBusy;

  WeighingState({
    this.weight = "0",
    this.plate = "---",
    this.message = "",
    this.isBusy = false,
  });

  WeighingState copyWith({
    String? weight,
    String? plate,
    String? message,
    bool? isBusy,
  }) {
    return WeighingState(
      weight: weight ?? this.weight,
      plate: plate ?? this.plate,
      // nếu không truyền message thì reset về rỗng sau khi UI đọc xong
      message: message ?? "",
      isBusy: isBusy ?? this.isBusy,
    );
  }
}

/// =======================
/// 3. BLOC (Logic chính)
/// =======================
class WeighingBloc extends Bloc<WeighingEvent, WeighingState> {
  final WeighingRepository _repository;
  HubConnection? _hubConnection;

  WeighingBloc(this._repository) : super(WeighingState()) {
    on<InitSignalR>(_onInitSignalR);
    on<UpdateRealtimeData>(_onUpdateRealtimeData);
    on<SubmitTicket>(_onSubmitTicket);
    on<TriggerBarrier>(_onTriggerBarrier);
    on<SyncOffline>(_onSyncOffline);
  }

  /// --- Kết nối SignalR ---
  Future<void> _onInitSignalR(
    InitSignalR event,
    Emitter<WeighingState> emit,
  ) async {
    try {
      // Lấy IP/API URL động từ Config
      final baseUrl = await AppConfig.getApiUrl();
      final hubUrl = "$baseUrl/weighthub";

      // Nếu đã có kết nối thì dừng trước khi tạo kết nối mới
      if (_hubConnection?.state == HubConnectionState.connected) {
        await _hubConnection?.stop();
      }

      _hubConnection = HubConnectionBuilder()
          .withUrl(hubUrl)
          .withAutomaticReconnect()
          .build();

      // Nhận số cân
      _hubConnection?.on("ReceiveWeight", (arguments) {
        if (arguments != null && arguments.isNotEmpty) {
          add(UpdateRealtimeData(weight: arguments[0].toString()));
        }
      });

      // Nhận biển số
      _hubConnection?.on("ReceiveLicensePlate", (arguments) {
        if (arguments != null && arguments.isNotEmpty) {
          add(UpdateRealtimeData(plate: arguments[0].toString()));
        }
      });

      await _hubConnection?.start();
      emit(state.copyWith(message: "Đã kết nối SignalR tới $baseUrl"));
    } catch (e) {
      // Cho phép chạy offline nếu lỗi kết nối
      print("Lỗi kết nối SignalR: $e");
      emit(
        state.copyWith(
          message: "Không thể kết nối Server (Chế độ Offline)",
        ),
      );
    }
  }

  /// --- Cập nhật realtime lên UI ---
  void _onUpdateRealtimeData(
    UpdateRealtimeData event,
    Emitter<WeighingState> emit,
  ) {
    emit(
      state.copyWith(
        weight: event.weight ?? state.weight,
        plate: event.plate ?? state.plate,
      ),
    );
  }

  /// --- Lưu phiếu cân ---
  Future<void> _onSubmitTicket(
    SubmitTicket event,
    Emitter<WeighingState> emit,
  ) async {
    emit(state.copyWith(isBusy: true));

    try {
      // Xử lý biển số
      String finalPlate = state.plate;
      if (finalPlate == "---" || finalPlate.trim().isEmpty) {
        finalPlate = "XE_LA";
      }

      final double grossWeight = double.tryParse(state.weight) ?? 0;

      // Map sang model hiện tại: chỉ có khoiLuongTong/Bi/Hang
      final phieu = PhieuCanModel(
        bienSo: finalPlate,
        khoiLuongTong: grossWeight,
        khoiLuongBi: 0, // TODO: thay bằng khối lượng bì thực tế nếu có
        khoiLuongHang: grossWeight, // hoặc grossWeight - khoiLuongBi
        thoiGian: DateTime.now().toIso8601String(),
        // Nếu sau này bạn thêm field ghiChu vào model,
        // có thể truyền thêm ở đây.
      );

      final String result = await _repository.saveTicket(phieu);

      emit(
        state.copyWith(
          isBusy: false,
          message: result,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isBusy: false,
          message: "Lỗi lưu phiếu: $e",
        ),
      );
    }
  }

  /// --- Mở barrier ---
  Future<void> _onTriggerBarrier(
    TriggerBarrier event,
    Emitter<WeighingState> emit,
  ) async {
    final bool success = await _repository.openBarrier();
    emit(
      state.copyWith(
        message: success
            ? "Đã gửi lệnh mở Barrier"
            : "Lỗi: Không thể mở Barrier",
      ),
    );
  }

  /// --- Đồng bộ dữ liệu offline ---
  Future<void> _onSyncOffline(
    SyncOffline event,
    Emitter<WeighingState> emit,
  ) async {
    emit(
      state.copyWith(
        isBusy: true,
        message: "Đang đồng bộ dữ liệu...",
      ),
    );

    final int count = await _repository.syncData();

    emit(
      state.copyWith(
        isBusy: false,
        message: "Đồng bộ hoàn tất: $count phiếu.",
      ),
    );
  }

  @override
  Future<void> close() async {
    await _hubConnection?.stop();
    _hubConnection = null;
    return super.close();
  }
}
