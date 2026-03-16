import 'package:dio/dio.dart';
import 'package:keepsyn_app/src/core/constants/standard_response.dart';
import 'package:keepsyn_app/src/core/error/exceptions.dart';
import 'package:keepsyn_app/src/features/integrations/data/enums/integration_status.dart';

class YouTubeRemoteDataSource {
  final Dio _dio;

  YouTubeRemoteDataSource(this._dio);

  Future<IntegrationStatus> getStatus() async {
    try {
      final response = await _dio.get('/v1/integrations/youtube/status');
      final stdRes = StandardResponse.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
      final statusString = stdRes.data?['status'] as String? ?? 'notConnected';
      return IntegrationStatus.values.firstWhere(
        (value) => value.name == statusString,
        orElse: () => IntegrationStatus.error,
      );
    } on DioException catch (e) {
      throw ServerException(_extractBackendMessage(e));
    } catch (e) {
      throw ServerException('Error obteniendo estado de YouTube: $e');
    }
  }

  Future<void> linkAccount({required String serverAuthCode}) async {
    if (serverAuthCode.isEmpty) {
      throw const ServerException(
        'No se recibio serverAuthCode para YouTube.',
      );
    }

    try {
      final response = await _dio.post(
        '/v1/integrations/youtube/link',
        data: {'serverAuthCode': serverAuthCode},
      );
      final stdRes = StandardResponse.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
      if (!stdRes.isOk) {
        throw ServerException(stdRes.message);
      }
    } on DioException catch (e) {
      throw ServerException(_extractBackendMessage(e));
    } catch (e) {
      throw ServerException('Fallo al vincular YouTube: $e');
    }
  }

  Future<void> unlinkAccount() async {
    try {
      final response = await _dio.post('/v1/integrations/youtube/unlink');
      final stdRes = StandardResponse.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
      if (!stdRes.isOk) {
        throw ServerException(stdRes.message);
      }
    } on DioException catch (e) {
      throw ServerException(_extractBackendMessage(e));
    } catch (e) {
      throw ServerException('Fallo al desvincular YouTube: $e');
    }
  }

  String _extractBackendMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      final message = data['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message;
      }
    }
    final code = e.response?.statusCode;
    if (code != null) {
      return 'Error HTTP $code en integracion YouTube.';
    }
    return e.message ?? 'Error de red en integracion YouTube.';
  }
}
