package com.vehicle.check.repository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.vehicle.check.domain.Task;
import com.vehicle.check.dto.DriverStatDTO;
import com.vehicle.check.dto.StationQueueDTO;

public interface TaskRepository extends JpaRepository<Task, Long> {

    Optional<Task> findByTaskNo(String taskNo);

    List<Task> findAllByOrderByIdAsc();

    List<Task> findByStatusOrderByIdAsc(String status);

    List<Task> findByStatusInAndCurrentStationIdInOrderByIdAsc(List<String> statuses, List<Long> stationIds);

    List<Task> findByDriverIdAndCheckDateOrderByScheduleHourAsc(Long driverId, LocalDate checkDate);

    List<Task> findByVehicleIdAndCheckDate(Long vehicleId, LocalDate checkDate);

    boolean existsByVehicleIdAndCheckDate(Long vehicleId, LocalDate checkDate);

    long countByStatusIn(List<String> statuses);

    /**
     * 跨线恢复 CAS 迁移：仅当任务仍停在原线原工位且仍在检才改写到目标线。
     * 返回 0 表示另一名值班员已抢先处置（或任务已被总结），本次转线必须整体回滚。
     */
    @Modifying(clearAutomatically = true)
    @Query("update Task t set t.lineId = :toLineId, t.currentStationId = :toStationId "
            + "where t.id = :id and t.lineId = :fromLineId and t.currentStationId = :fromStationId "
            + "and t.status in ('CHECKING', 'RETEST')")
    int transferLine(@Param("id") Long id, @Param("toLineId") Long toLineId,
                     @Param("toStationId") Long toStationId, @Param("fromLineId") Long fromLineId,
                     @Param("fromStationId") Long fromStationId);

    /**
     * 各工位当前排队车辆数（在检/复检的任务按当前工位分组）
     */
    @Query("select new com.vehicle.check.dto.StationQueueDTO(t.currentStationId, count(t)) "
            + "from Task t "
            + "where t.status in ('CHECKING', 'RETEST') and t.currentStationId is not null "
            + "group by t.currentStationId")
    List<StationQueueDTO> countQueueGroupByStation();

    /**
     * 按引车员统计当日台次
     */
    @Query("select new com.vehicle.check.dto.DriverStatDTO(t.driverId, count(t)) "
            + "from Task t "
            + "where t.checkDate = :date and t.driverId is not null "
            + "group by t.driverId")
    List<DriverStatDTO> countGroupByDriverAndDate(@Param("date") LocalDate date);
}
