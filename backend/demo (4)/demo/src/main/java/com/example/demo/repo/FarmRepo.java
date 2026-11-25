package com.example.demo.repo;
import com.example.demo.model.*; import org.springframework.data.jpa.repository.JpaRepository; import java.util.*;
public interface FarmRepo extends JpaRepository<Farm,Long>{ List<Farm> findByOwnerId(Long id); Optional<Farm> findByIdAndOwnerId(Long id,Long ownerId); }
