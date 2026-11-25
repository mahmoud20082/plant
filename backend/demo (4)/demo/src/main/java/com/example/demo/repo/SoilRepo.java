package com.example.demo.repo;
import com.example.demo.model.*; import org.springframework.data.jpa.repository.JpaRepository; import java.util.*;
public interface SoilRepo extends JpaRepository<SoilMeasurement,Long>{ List<SoilMeasurement> findByCropIdAndCropFarmOwnerIdOrderByMeasurementDateDesc(Long cropId,Long ownerId); }
