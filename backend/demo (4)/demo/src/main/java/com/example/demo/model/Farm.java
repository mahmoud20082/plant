package com.example.demo.model;
import jakarta.persistence.*;
import jakarta.validation.constraints.*;
@Entity @Table(name="farms") public class Farm {
 @Id @GeneratedValue(strategy=GenerationType.IDENTITY) public Long id;
 @NotBlank @Column(nullable=false) public String name;
 @NotBlank @Column(nullable=false) public String location;
 @Positive @Column(nullable=false) public double area;
 @ManyToOne(optional=false,fetch=FetchType.LAZY) @JoinColumn(name="user_id",nullable=false) public Farmer owner;
 public Farm() {}
}
