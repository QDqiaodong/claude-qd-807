package com.vehicle.check.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;

import com.vehicle.check.domain.TransferRecord;

public interface TransferRecordRepository extends JpaRepository<TransferRecord, Long> {

    List<TransferRecord> findByTaskIdOrderByIdDesc(Long taskId);

    List<TransferRecord> findTop20ByOrderByIdDesc();
}
