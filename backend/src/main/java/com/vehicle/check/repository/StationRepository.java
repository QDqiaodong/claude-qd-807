package com.vehicle.check.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.vehicle.check.domain.Station;

public interface StationRepository extends JpaRepository<Station, Long> {

    List<Station> findByLineIdOrderBySeqNoAsc(Long lineId);

    List<Station> findByStationTypeOrderByIdAsc(String stationType);

    List<Station> findByStatus(String status);

    long countByStatus(String status);

    /**
     * 跨线恢复 CAS 占位：仅当目标工位仍是空闲才置为占用。
     * 返回 0 表示确认瞬间工位已被占用或状态变化，本次转线必须整体回滚。
     */
    @Modifying(clearAutomatically = true)
    @Query("update Station s set s.status = 'OCCUPIED' where s.id = :id and s.status = 'IDLE'")
    int occupyIfIdle(@Param("id") Long id);

    /**
     * 跨线恢复释放旧工位：仅当工位仍被占用才释放；故障工位保持故障，待维修后恢复。
     */
    @Modifying(clearAutomatically = true)
    @Query("update Station s set s.status = 'IDLE' where s.id = :id and s.status = 'OCCUPIED'")
    int releaseIfOccupied(@Param("id") Long id);
}
