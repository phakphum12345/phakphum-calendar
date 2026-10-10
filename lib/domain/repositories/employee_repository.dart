import '../../core/result/result.dart';
import '../entities/employee.dart';

abstract interface class EmployeeRepository {
  Future<Result<List<Employee>>> findAll({bool activeOnly = true});
  Future<Result<Employee?>> findById(String id);
  Future<Result<List<Employee>>> search(String query);
  Future<Result<Employee>> save(Employee employee);
  Future<Result<List<Employee>>> saveAll(List<Employee> employees);
  Future<Result<void>> delete(String id);
}
