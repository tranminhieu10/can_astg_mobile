import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:signalr_core/signalr_core.dart';
import '../../data/services/config_service.dart';
import '../../data/repositories/weighing_repository.dart';
import '../../data/models/phieu_can_model.dart';

// --- EVENTS ---
abstract class WeighingEvent {}

class InitSignalR extends WeighingEvent {}

class UpdateRealtimeData extends WeighingEvent {
  final String? weight;
  final String? plate;
  UpdateRealtimeData({this.weight, this.plate});
}

class CheckForUnfinishedTicket extends WeighingEvent {
  final String plate;
  CheckForUnfinishedTicket(this.plate);
}

class WeighGross extends WeighingEvent {
  final String maCongTyNhap;
  final String maCongTyBan;
  final String maLoai;
  final String note;

  WeighGross({
    required this.maCongTyNhap, 
    required this.maCongTyBan, 
    required this.maLoai, 
    this.note = ""
  });
}

class WeighTare extends WeighingEvent {}
class SaveTicket extends WeighingEvent {}
class ClearWeighing extends WeighingEvent {}
class TriggerBarrier extends WeighingEvent {}
class SyncDataEvent extends WeighingEvent {}
class DeletePhieuCan extends WeighingEvent { 
  final int id; 
  DeletePhieuCan(this.id); 
}

// --- STATE ---
class WeighingState {
  final String weight;
  final String plate;
  final String message;
  final bool isBusy;
  final PhieuCanModel? phieuHienTai;
  final bool canTongDone;
  final bool canBiDone;
  final bool isUpdating; 

  WeighingState({
    this.weight = "0",
    this.plate = "---",
    this.message = "",
    this.isBusy = false,
    this.phieuHienTai,
    this.canTongDone = false,
    this.canBiDone = false,
    this.isUpdating = false,
  });

  WeighingState copyWith({
    String? weight,
    String? plate,
    String? message,
    bool? isBusy,
    PhieuCanModel? phieuHienTai, 
    bool? canTongDone,
    bool? canBiDone,
    bool? isUpdating,
  }) {
    return WeighingState(
      weight: weight ?? this.weight,
      plate: plate ?? this.plate,
      message: message ?? "",
      isBusy: isBusy ?? this.isBusy,
      phieuHienTai: phieuHienTai,
      canTongDone: canTongDone ?? this.canTongDone,
      canBiDone: canBiDone ?? this.canBiDone,
      isUpdating: isUpdating ?? this.isUpdating,
    );
  }
}

// --- BLOC ---
class WeighingBloc extends Bloc<WeighingEvent, WeighingState> {
  final WeighingRepository _repository;
  HubConnection? _hubConnection;
  String _lastCheckedPlate = "";

  WeighingBloc(this._repository) : super(WeighingState(phieuHienTai: null)) {
    on<InitSignalR>(_onInitSignalR);
    on<UpdateRealtimeData>(_onUpdateRealtimeData);
    on<CheckForUnfinishedTicket>(_onCheckForUnfinishedTicket);
    on<WeighGross>(_onWeighGross);
    on<WeighTare>(_onWeighTare);
    on<SaveTicket>(_onSaveTicket);
    on<ClearWeighing>(_onClearWeighing);
    on<TriggerBarrier>(_onTriggerBarrier);
    on<SyncDataEvent>(_onSyncData);
    on<DeletePhieuCan>(_onDeletePhieuCan);
  }

  Future<void> _onInitSignalR(InitSignalR event, Emitter<WeighingState> emit) async {
    try {
      final baseUrl = await AppConfig.getApiUrl();
      // Loại bỏ đuôi /swagger nếu có, trỏ về hub
      final cleanUrl = baseUrl.replaceAll('/swagger', '').replaceAll(RegExp(r'/$'), '');
      final hubUrl = "$cleanUrl/weighthub"; 
      
      if (_hubConnection?.state == HubConnectionState.connected) {
        await _hubConnection?.stop();
      }

      _hubConnection = HubConnectionBuilder()
          .withUrl(hubUrl)
          .withAutomaticReconnect()
          .build();

      _hubConnection?.on("ReceiveWeight", (args) {
        if (args != null && args.isNotEmpty) {
           add(UpdateRealtimeData(weight: args[0].toString()));
        }
      });

      _hubConnection?.on("ReceiveLicensePlate", (args) {
        if (args != null && args.isNotEmpty) {
           add(UpdateRealtimeData(plate: args[0].toString()));
        }
      });

      // Lắng nghe sự kiện DataChanged từ WPF/API gửi tới
      _hubConnection?.on("DataChanged", (args) {
          add(SyncDataEvent());
      });

      await _hubConnection?.start();
      print("✅ SignalR Connected: $hubUrl");

    } catch (e) { 
      print("❌ SignalR Error: $e"); 
    }
  }

  void _onUpdateRealtimeData(UpdateRealtimeData event, Emitter<WeighingState> emit) {
    String? newPlate = event.plate;
    if (newPlate != null && newPlate.isNotEmpty && newPlate != "---" && newPlate != _lastCheckedPlate) {
      _lastCheckedPlate = newPlate;
      add(CheckForUnfinishedTicket(newPlate));
    }
    
    emit(state.copyWith(weight: event.weight, plate: event.plate));
  }

  Future<void> _onCheckForUnfinishedTicket(CheckForUnfinishedTicket event, Emitter<WeighingState> emit) async {
    if (state.phieuHienTai != null) return;

    final unfinishedTicket = await _repository.findLatestUnfinishedTicketByPlate(event.plate);
    if (unfinishedTicket != null) {
      emit(state.copyWith(
        phieuHienTai: unfinishedTicket,
        canTongDone: true, 
        canBiDone: false,
        isUpdating: true,
        message: "Tìm thấy phiếu chờ: ${event.plate}",
      ));
    }
  }

  Future<void> _onWeighGross(WeighGross event, Emitter<WeighingState> emit) async {
     if (state.isUpdating) return;
    emit(state.copyWith(isBusy: true));

    String finalPlate = state.plate.trim();
    if (finalPlate == "---" || finalPlate.isEmpty) finalPlate = "XE_LA";
    
    final double grossWeight = double.tryParse(state.weight) ?? 0;
    if (grossWeight <= 0) {
      emit(state.copyWith(isBusy: false, message: "Lỗi: Khối lượng = 0"));
      return;
    }

    final newTicket = PhieuCanModel(
      bienSo: finalPlate,
      maCongTyNhap: event.maCongTyNhap, 
      maCongTyBan: event.maCongTyBan,
      maLoai: event.maLoai,
      tlTong: grossWeight,
      tlBi: 0,
      tlHang: 0,
      thoiGianCanTong: DateTime.now().toIso8601String(),
      nguoiCan: "MobileUser",
      ghiChu: event.note,
    );

    emit(state.copyWith(
      isBusy: false,
      phieuHienTai: newTicket,
      canTongDone: true,
      canBiDone: false,
      isUpdating: false,
      message: "Đã chốt cân tổng",
    ));
  }

  Future<void> _onWeighTare(WeighTare event, Emitter<WeighingState> emit) async {
    if (state.phieuHienTai == null || !state.canTongDone) return;

    emit(state.copyWith(isBusy: true));
    final double tareWeight = double.tryParse(state.weight) ?? 0;

    if (tareWeight <= 0) {
      emit(state.copyWith(isBusy: false, message: "Lỗi: Khối lượng bì = 0"));
      return;
    }
    
    final updatedTicket = state.phieuHienTai!.copyWith(
      tlBi: tareWeight,
      tlHang: (state.phieuHienTai!.tlTong - tareWeight).abs(),
      thoiGianCanBi: DateTime.now().toIso8601String(),
    );

    emit(state.copyWith(
      isBusy: false,
      phieuHienTai: updatedTicket,
      canBiDone: true,
      message: "Đã chốt cân bì",
    ));
  }

  String? _validateBeforeSave() {
    final currentTicket = state.phieuHienTai;
    if (currentTicket == null) {
      return "Không có phiếu để lưu.";
    }
    if (!state.canTongDone) {
      return "Chưa chốt cân tổng.";
    }
    // Có thể bổ sung thêm validate khác (khách hàng, loại hàng, ...) ở đây sau này.
    return null;
  }

  Future<void> _onSaveTicket(SaveTicket event, Emitter<WeighingState> emit) async {
    // Validate phiếu trước khi lưu
    final validationError = _validateBeforeSave();
    if (validationError != null) {
      emit(state.copyWith(message: validationError));
      return;
    }

    final currentTicket = state.phieuHienTai;
    if (currentTicket == null) {
      emit(state.copyWith(message: "Không có phiếu để lưu."));
      return;
    }

    emit(state.copyWith(isBusy: true));
    try {
      final String result;
      if (state.isUpdating && currentTicket.id != null) {
        result = await _repository.updateTicket(currentTicket);
      } else {
        result = await _repository.saveTicket(currentTicket);
      }

      final bool isError = result.startsWith("Lỗi");

      if (!isError && _hubConnection?.state == HubConnectionState.connected) {
        await _hubConnection?.invoke("NotifyDataChanged");
        await _hubConnection?.invoke("SendBarrierCommand", args: ["OPEN"]);
      }

      if (isError) {
        emit(state.copyWith(isBusy: false, message: result));
      } else {
        emit(WeighingState(
          weight: state.weight,
          plate: state.plate,
          phieuHienTai: null,
          message: result,
        ));
        _lastCheckedPlate = "";
      }
    } catch (e) {
      emit(state.copyWith(isBusy: false, message: "Lỗi lưu: $e"));
    }
  }

  void _onClearWeighing(ClearWeighing event, Emitter<WeighingState> emit) {
    emit(WeighingState(weight: state.weight, plate: state.plate, phieuHienTai: null));
    _lastCheckedPlate = "";
  }

  Future<void> _onTriggerBarrier(TriggerBarrier event, Emitter<WeighingState> emit) async {
    bool ok = await _repository.openBarrier();
    emit(state.copyWith(message: ok ? "Lệnh mở Barrier đã gửi" : "Lỗi gửi lệnh"));
  }

  Future<void> _onSyncData(SyncDataEvent event, Emitter<WeighingState> emit) async {
    emit(state.copyWith(isBusy: true, message: "Đang đồng bộ..."));
    final String result = await _repository.syncData();
    emit(state.copyWith(isBusy: false, message: result));
  }

  Future<void> _onDeletePhieuCan(DeletePhieuCan event, Emitter<WeighingState> emit) async {
    await _repository.deletePhieuCan(event.id);
    emit(state.copyWith(message: "Đã xóa phiếu"));
  }

  @override
  Future<void> close() {
    _hubConnection?.stop();
    return super.close();
  }
}
