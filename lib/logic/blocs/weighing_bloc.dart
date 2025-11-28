import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:signalr_core/signalr_core.dart';

import '../../data/services/config_service.dart';
import '../../data/repositories/weighing_repository.dart';
import '../../data/models/phieu_can_model.dart';

/// =========================================================
/// 1. EVENTS: Các hành động từ giao diện gửi vào Bloc
/// =========================================================
abstract class WeighingEvent {}

// Khởi động kết nối SignalR để nhận dữ liệu cân/biển số
class InitSignalR extends WeighingEvent {}

// Cập nhật dữ liệu Realtime lên màn hình (Internal Event)
class UpdateRealtimeData extends WeighingEvent {
  final String? weight;
  final String? plate;
  UpdateRealtimeData({this.weight, this.plate});
}

// Người dùng nhấn nút "Lưu Phiếu Cân"
class SubmitTicket extends WeighingEvent {
  final String note;      // Ghi chú
  final String khachHang; // Khách hàng
  final String loaiHang;  // Loại hàng hóa

  SubmitTicket({
    this.note = "",
    this.khachHang = "Khách lẻ", 
    this.loaiHang = "Hàng thường"
  });
}

// Người dùng nhấn nút "Mở Barrier"
class TriggerBarrier extends WeighingEvent {}

// Sự kiện yêu cầu Đồng bộ (Khi vào màn hình Lịch sử hoặc Vuốt Refresh)
class SyncDataEvent extends WeighingEvent {} 


/// =========================================================
/// 2. STATE: Trạng thái dữ liệu của màn hình
/// =========================================================
class WeighingState {
  final String weight;  // Số cân hiện tại
  final String plate;   // Biển số hiện tại
  final String message; // Thông báo hiển thị (SnackBar)
  final bool isBusy;    // Trạng thái đang xử lý (Loading)

  WeighingState({
    this.weight = "0",
    this.plate = "---",
    this.message = "",
    this.isBusy = false,
  });

  // CopyWith giúp cập nhật state mà không làm mất dữ liệu cũ
  WeighingState copyWith({
    String? weight,
    String? plate,
    String? message,
    bool? isBusy,
  }) {
    return WeighingState(
      weight: weight ?? this.weight,
      plate: plate ?? this.plate,
      // Lưu ý: message mặc định reset về rỗng để không hiện lại thông báo cũ
      message: message ?? "", 
      isBusy: isBusy ?? this.isBusy,
    );
  }
}


/// =========================================================
/// 3. BLOC: Logic xử lý trung tâm
/// =========================================================
class WeighingBloc extends Bloc<WeighingEvent, WeighingState> {
  final WeighingRepository _repository;
  HubConnection? _hubConnection;

  WeighingBloc(this._repository) : super(WeighingState()) {
    on<InitSignalR>(_onInitSignalR);
    on<UpdateRealtimeData>(_onUpdateRealtimeData);
    on<SubmitTicket>(_onSubmitTicket);
    on<TriggerBarrier>(_onTriggerBarrier);
    on<SyncDataEvent>(_onSyncData);
  }

  /// ---------------------------------------------------
  /// XỬ LÝ KẾT NỐI SIGNALR (REALTIME)
  /// ---------------------------------------------------
  Future<void> _onInitSignalR(InitSignalR event, Emitter<WeighingState> emit) async {
    try {
      final baseUrl = await AppConfig.getApiUrl();
      final hubUrl = "$baseUrl/weighthub"; 

      // Ngắt kết nối cũ nếu có
      if (_hubConnection?.state == HubConnectionState.connected) {
        await _hubConnection?.stop();
      }

      // Cấu hình SignalR
      _hubConnection = HubConnectionBuilder()
          .withUrl(hubUrl)
          .withAutomaticReconnect() // Tự động kết nối lại khi rớt mạng
          .build();

      // Lắng nghe sự kiện từ Server gửi về
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

      await _hubConnection?.start();
      print("✅ Kết nối SignalR thành công tới: $hubUrl");
      
    } catch (e) {
      print("❌ Lỗi SignalR: $e");
      // Không emit lỗi ra UI để tránh làm phiền, chỉ log console
    }
  }

  /// ---------------------------------------------------
  /// CẬP NHẬT GIAO DIỆN (UI)
  /// ---------------------------------------------------
  void _onUpdateRealtimeData(UpdateRealtimeData event, Emitter<WeighingState> emit) {
    emit(state.copyWith(
      weight: event.weight ?? state.weight,
      plate: event.plate ?? state.plate,
    ));
  }

  /// ---------------------------------------------------
  /// XỬ LÝ LƯU PHIẾU (QUAN TRỌNG NHẤT)
  /// ---------------------------------------------------
  Future<void> _onSubmitTicket(SubmitTicket event, Emitter<WeighingState> emit) async {
    // 1. Bật trạng thái Loading
    emit(state.copyWith(isBusy: true)); 

    try {
      // 2. Chuẩn hóa dữ liệu đầu vào
      String finalPlate = state.plate;
      if (finalPlate == "---" || finalPlate.trim().isEmpty) {
        finalPlate = "XE_LA"; // Mặc định nếu không có biển số
      }

      final double grossWeight = double.tryParse(state.weight) ?? 0;

      // 3. Tạo Model Phiếu Cân
      final phieu = PhieuCanModel(
        bienSo: finalPlate,
        khoiLuongTong: grossWeight,
        khoiLuongBi: 0, // Hiện tại chưa trừ bì
        khoiLuongHang: grossWeight,
        thoiGian: DateTime.now().toIso8601String(),
        khachHang: event.khachHang,
        loaiHang: event.loaiHang,
        ghiChu: event.note,
        nguoiCan: "Admin", // TODO: Lấy từ User Session
        isSynced: 0 // QUAN TRỌNG: Mặc định là Offline (0)
      );

      // 4. Gọi Repository (Repository sẽ tự xử lý Offline -> Online)
      final String result = await _repository.saveTicket(phieu);

      // 5. Tắt Loading và hiển thị kết quả
      emit(state.copyWith(
        isBusy: false, 
        message: result 
      ));
    } catch (e) {
      emit(state.copyWith(
        isBusy: false, 
        message: "Lỗi lưu phiếu: $e"
      ));
    }
  }

  /// ---------------------------------------------------
  /// XỬ LÝ ĐỒNG BỘ DỮ LIỆU
  /// ---------------------------------------------------
  Future<void> _onSyncData(SyncDataEvent event, Emitter<WeighingState> emit) async {
    emit(state.copyWith(isBusy: true, message: "Đang đồng bộ dữ liệu..."));
    
    // Gọi hàm syncData (Đã bao gồm cả Up và Down)
    final String result = await _repository.syncData();

    emit(state.copyWith(
      isBusy: false,
      message: result, 
    ));
  }

  /// ---------------------------------------------------
  /// XỬ LÝ ĐIỀU KHIỂN BARRIER
  /// ---------------------------------------------------
  Future<void> _onTriggerBarrier(TriggerBarrier event, Emitter<WeighingState> emit) async {
    bool ok = await _repository.openBarrier();
    emit(state.copyWith(
      message: ok ? "Đã gửi lệnh mở Barrier" : "Lỗi: Không thể kết nối tới Barrier"
    ));
  }

  @override
  Future<void> close() async {
    await _hubConnection?.stop();
    return super.close();
  }
}