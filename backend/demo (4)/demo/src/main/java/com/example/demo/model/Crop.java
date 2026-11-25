package com.example.demo.model;
import jakarta.persistence.*;
import jakarta.validation.constraints.*;
import java.time.LocalDate;
@Entity @Table(name="crops") public class Crop {
 @Id @GeneratedValue(strategy=GenerationType.IDENTITY) public Long id;
 @ManyToOne(optional=false,fetch=FetchType.EAGER) @JoinColumn(name="farm_id",nullable=false) public Farm farm;
 @NotBlank @Column(nullable=false) public String cropType;
 @NotNull @Column(nullable=false) public LocalDate plantingDate;
 public LocalDate expectedHarvestDate;
 @NotBlank public String growthStage="Seedling";
 @NotBlank public String status="Healthy";
 public Crop() {}
}

