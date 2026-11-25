package com.example.demo.repo;
import com.example.demo.model.*; import org.springframework.data.jpa.repository.JpaRepository; import java.util.*;
public interface ScanRepo extends JpaRepository<ScanHistory,Long>{ List<ScanHistory> findByCropIdAndCropFarmOwnerIdOrderByScanDateDesc(Long cropId,Long ownerId); }
