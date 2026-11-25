package com.example.demo.model;
import jakarta.persistence.*;
import jakarta.validation.constraints.*;
import java.time.Instant;
@Entity @Table(name="irrigation_logs") public class IrrigationLog {
 @Id @GeneratedValue(strategy=GenerationType.IDENTITY) public Long id;
 @ManyToOne(optional=false) @JoinColumn(name="crop_id",nullable=false) public Crop crop;
 @PositiveOrZero public double waterAmount;
 @Min(0) @Max(100) public int soilMoisture;
 @Column(nullable=false) public Instant irrigationDate=Instant.now();
 public String notes;
 public IrrigationLog() {}
}
