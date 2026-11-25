package com.example.demo.repo;
import com.example.demo.model.*; import org.springframework.data.jpa.repository.JpaRepository; import java.util.*;
public interface CropRepo extends JpaRepository<Crop,Long>{ List<Crop> findByFarmOwnerId(Long ownerId); Optional<Crop> findByIdAndFarmOwnerId(Long id,Long ownerId); List<Crop> findByFarmIdAndFarmOwnerId(Long farmId,Long ownerId); }
