package com.vehicle.check.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;

import com.vehicle.check.domain.Station;

public interface StationRepository extends JpaRepository<Station, Long> {

    List<Station> findByLineIdOrderBySeqNoAsc(Long lineId);

    List<Station> findByStationTypeOrderByIdAsc(String stationType);

    long countByStatus(String status);
}
