package com.example.demo.repo;
import com.example.demo.model.*; import org.springframework.data.jpa.repository.JpaRepository; import java.util.*;
public interface IrrigationRepo extends JpaRepository<IrrigationLog,Long>{ List<IrrigationLog> findByCropIdAndCropFarmOwnerIdOrderByIrrigationDateDesc(Long cropId,Long ownerId); }
