package com.example.demo.model;
import jakarta.persistence.*;
import jakarta.validation.constraints.*;
import java.time.Instant;
@Entity @Table(name="soil_measurements") public class SoilMeasurement {
 @Id @GeneratedValue(strategy=GenerationType.IDENTITY) public Long id;
 @ManyToOne(optional=false) @JoinColumn(name="crop_id",nullable=false) public Crop crop;
 @Min(0) @Max(100) public int moisturePercentage;
 public Double temperature;
 @Column(nullable=false) public Instant measurementDate=Instant.now();
 public SoilMeasurement() {}
}
