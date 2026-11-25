package com.example.demo.repo;
import com.example.demo.model.*; import org.springframework.data.jpa.repository.JpaRepository; import java.util.*;
public interface FarmerRepo extends JpaRepository<Farmer,Long>{ Optional<Farmer> findByEmail(String email); }
