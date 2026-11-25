package com.example.demo.model;
import jakarta.persistence.*;
import jakarta.validation.constraints.*;
import java.time.Instant;
@Entity @Table(name="farmers") public class Farmer {
 @Id @GeneratedValue(strategy=GenerationType.IDENTITY) public Long id;
 @NotBlank @Column(nullable=false) public String fullName;
 @Email @NotBlank @Column(nullable=false,unique=true) public String email;
 @NotBlank @Column(nullable=false) public String passwordHash;
 @Column(nullable=false) public Instant createdAt=Instant.now();
 public Farmer() {}
}
