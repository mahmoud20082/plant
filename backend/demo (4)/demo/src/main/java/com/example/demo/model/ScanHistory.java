package com.example.demo.model;
import jakarta.persistence.*;
import jakarta.validation.constraints.*;
import java.time.Instant;
@Entity @Table(name="scan_history") public class ScanHistory {
 @Id @GeneratedValue(strategy=GenerationType.IDENTITY) public Long id;
 @ManyToOne(optional=false) @JoinColumn(name="crop_id",nullable=false) public Crop crop;
 public String imagePath;
 @Column(nullable=false) public String predictedDisease;
 @DecimalMin("0.0") @DecimalMax("1.0") public double confidence;
 @Column(nullable=false) public Instant scanDate=Instant.now();
 @Column(length=2000) public String recommendations;
 public ScanHistory() {}
}
