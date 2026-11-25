package com.example.demo.api;
import com.example.demo.model.*;import com.example.demo.repo.*;import com.example.demo.security.Sessions;import jakarta.validation.Valid;import jakarta.validation.constraints.*;import org.springframework.http.*; import org.springframework.web.server.ResponseStatusException;import org.springframework.web.bind.annotation.*;import java.util.*;
@RestController @RequestMapping("/api/soil-measurements") public class SoilController{
 public record Input(@NotNull Long cropId,@Min(0) @Max(100) int moisturePercentage,@DecimalMin("-50") @DecimalMax("80") Double temperature){}
 private final SoilRepo measurements;private final CropRepo crops;public SoilController(SoilRepo m,CropRepo c){measurements=m;crops=c;}
 private Long uid(String h){Long id=Sessions.user(h);if(id==null)throw new ResponseStatusException(HttpStatus.UNAUTHORIZED);return id;}
 @PostMapping public ResponseEntity<?> create(@RequestHeader(value="Authorization",required=false)String h,@Valid @RequestBody Input i){Crop c=crops.findByIdAndFarmOwnerId(i.cropId(),uid(h)).orElseThrow(()->new ResponseStatusException(HttpStatus.NOT_FOUND));SoilMeasurement m=new SoilMeasurement();m.crop=c;m.moisturePercentage=i.moisturePercentage();m.temperature=i.temperature();return ResponseEntity.status(201).body(measurements.save(m));}
 @GetMapping("/{cropId}") public List<SoilMeasurement> list(@RequestHeader(value="Authorization",required=false)String h,@PathVariable Long cropId){return measurements.findByCropIdAndCropFarmOwnerIdOrderByMeasurementDateDesc(cropId,uid(h));}
}


