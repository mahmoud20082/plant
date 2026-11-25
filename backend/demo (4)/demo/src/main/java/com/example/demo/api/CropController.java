package com.example.demo.api;
import com.example.demo.model.*; import com.example.demo.repo.*; import com.example.demo.security.Sessions;
import jakarta.validation.Valid; import jakarta.validation.constraints.*; import org.springframework.http.*; import org.springframework.web.server.ResponseStatusException; import org.springframework.web.bind.annotation.*; import java.time.*; import java.util.*;
@RestController @RequestMapping("/api/crops") public class CropController {
 public record CropInput(@NotNull Long farmId,@NotBlank String cropType,@NotNull LocalDate plantingDate,LocalDate expectedHarvestDate,@NotBlank String growthStage,@NotBlank String status){}
 private final CropRepo crops;private final FarmRepo farms;private final ScanRepo scans;private final IrrigationRepo irrigation;private final SoilRepo soil;public CropController(CropRepo c,FarmRepo f,ScanRepo s,IrrigationRepo i,SoilRepo m){crops=c;farms=f;scans=s;irrigation=i;soil=m;}
 private Long user(String h){Long id=Sessions.user(h);if(id==null)throw new ResponseStatusException(HttpStatus.UNAUTHORIZED,"Bearer token required");return id;}
 private Map<String,Object> view(Crop c){return Map.of("id",c.id,"farmId",c.farm.id,"farmName",c.farm.name,"cropType",c.cropType,"plantingDate",c.plantingDate,"expectedHarvestDate",c.expectedHarvestDate==null?"":c.expectedHarvestDate,"growthStage",c.growthStage,"status",c.status);}
 @GetMapping public List<Map<String,Object>> all(@RequestHeader(value="Authorization",required=false)String h){return crops.findByFarmOwnerId(user(h)).stream().map(this::view).toList();}
 @PostMapping public ResponseEntity<?> create(@RequestHeader(value="Authorization",required=false)String h,@Valid @RequestBody CropInput in){Long uid=user(h);Crop c=new Crop();c.farm=farms.findByIdAndOwnerId(in.farmId(),uid).orElseThrow(()->new ResponseStatusException(HttpStatus.NOT_FOUND,"Farm not found"));fill(c,in);return ResponseEntity.status(201).body(view(crops.save(c)));}
 @GetMapping("/{id}") public Map<String,Object> get(@RequestHeader(value="Authorization",required=false)String h,@PathVariable Long id){return crops.findByIdAndFarmOwnerId(id,user(h)).map(this::view).orElseThrow(()->new ResponseStatusException(HttpStatus.NOT_FOUND));}
 @PutMapping("/{id}") public Map<String,Object> update(@RequestHeader(value="Authorization",required=false)String h,@PathVariable Long id,@Valid @RequestBody CropInput in){Crop c=crops.findByIdAndFarmOwnerId(id,user(h)).orElseThrow(()->new ResponseStatusException(HttpStatus.NOT_FOUND));c.farm=farms.findByIdAndOwnerId(in.farmId(),Sessions.user(h)).orElseThrow(()->new ResponseStatusException(HttpStatus.NOT_FOUND));fill(c,in);return view(crops.save(c));}
 @DeleteMapping("/{id}") public ResponseEntity<?> delete(@RequestHeader(value="Authorization",required=false)String h,@PathVariable Long id){Crop c=crops.findByIdAndFarmOwnerId(id,user(h)).orElseThrow(()->new ResponseStatusException(HttpStatus.NOT_FOUND));scans.deleteAll(scans.findByCropIdAndCropFarmOwnerIdOrderByScanDateDesc(id,user(h)));irrigation.deleteAll(irrigation.findByCropIdAndCropFarmOwnerIdOrderByIrrigationDateDesc(id,user(h)));soil.deleteAll(soil.findByCropIdAndCropFarmOwnerIdOrderByMeasurementDateDesc(id,user(h)));crops.delete(c);return ResponseEntity.noContent().build();}
 private void fill(Crop c,CropInput i){c.cropType=i.cropType();c.plantingDate=i.plantingDate();c.expectedHarvestDate=i.expectedHarvestDate();c.growthStage=i.growthStage();c.status=i.status();}
}



