package com.example.demo.api;
import com.example.demo.model.*;import com.example.demo.repo.*;import com.example.demo.security.Sessions;import jakarta.validation.Valid;import jakarta.validation.constraints.*;import org.springframework.http.*; import org.springframework.web.server.ResponseStatusException;import org.springframework.web.bind.annotation.*;import java.time.*;import java.util.*;
@RestController @RequestMapping("/api/irrigation") public class IrrigationController{
 public record Input(@NotNull Long cropId,@PositiveOrZero double waterAmount,@Min(0) @Max(100) int soilMoisture,String notes){}
 private final IrrigationRepo logs;private final CropRepo crops;public IrrigationController(IrrigationRepo l,CropRepo c){logs=l;crops=c;}
 private Long uid(String h){Long id=Sessions.user(h);if(id==null)throw new ResponseStatusException(HttpStatus.UNAUTHORIZED);return id;}
 @PostMapping public ResponseEntity<?> create(@RequestHeader(value="Authorization",required=false)String h,@Valid @RequestBody Input i){Crop c=crops.findByIdAndFarmOwnerId(i.cropId(),uid(h)).orElseThrow(()->new ResponseStatusException(HttpStatus.NOT_FOUND));IrrigationLog l=new IrrigationLog();l.crop=c;l.waterAmount=i.waterAmount();l.soilMoisture=i.soilMoisture();l.notes=i.notes();return ResponseEntity.status(201).body(logs.save(l));}
 @GetMapping("/{cropId}") public List<IrrigationLog> list(@RequestHeader(value="Authorization",required=false)String h,@PathVariable Long cropId){return logs.findByCropIdAndCropFarmOwnerIdOrderByIrrigationDateDesc(cropId,uid(h));}
}


