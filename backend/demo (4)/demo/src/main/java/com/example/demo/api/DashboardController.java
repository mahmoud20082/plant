package com.example.demo.api;
import com.example.demo.repo.*;import com.example.demo.security.Sessions;import org.springframework.http.*; import org.springframework.web.server.ResponseStatusException;import org.springframework.web.bind.annotation.*;import java.util.*;
@RestController @RequestMapping("/api/dashboard") public class DashboardController{
 private final FarmRepo farms;private final CropRepo crops;private final ScanRepo scans;private final IrrigationRepo irrigation;private final SoilRepo soil;public DashboardController(FarmRepo f,CropRepo c,ScanRepo s,IrrigationRepo i,SoilRepo m){farms=f;crops=c;scans=s;irrigation=i;soil=m;}
 @GetMapping("/{farmId}") public Map<String,Object> get(@RequestHeader(value="Authorization",required=false)String h,@PathVariable Long farmId){Long uid=Sessions.user(h);if(uid==null)throw new ResponseStatusException(HttpStatus.UNAUTHORIZED);var farm=farms.findByIdAndOwnerId(farmId,uid).orElseThrow(()->new ResponseStatusException(HttpStatus.NOT_FOUND));var cs=crops.findByFarmIdAndFarmOwnerId(farmId,uid);return Map.of("farmId",farm.id,"farmName",farm.name,"totalCrops",cs.size(),"healthyCrops",cs.stream().filter(c->"Healthy".equalsIgnoreCase(c.status)).count(),"cropsRequiringAttention",cs.stream().filter(c->!"Healthy".equalsIgnoreCase(c.status)).count(),"weather",Map.of("available",false,"message","Weather provider is not configured"),"crops",cs.stream().map(c->Map.of("id",c.id,"cropType",c.cropType,"status",c.status,"growthStage",c.growthStage)).toList());}
}


