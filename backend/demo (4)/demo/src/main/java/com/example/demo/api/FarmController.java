package com.example.demo.api;
import com.example.demo.model.*; import com.example.demo.repo.*; import com.example.demo.security.Sessions;
import jakarta.validation.Valid; import jakarta.validation.constraints.*; import org.springframework.http.*; import org.springframework.web.server.ResponseStatusException; import org.springframework.web.bind.annotation.*; import java.util.*;
@RestController @RequestMapping("/api/farms") public class FarmController {
 public record FarmInput(@NotBlank String name,@NotBlank String location,@Positive double area){}
 private final FarmRepo farms;private final FarmerRepo farmers;private final CropRepo crops;private final ScanRepo scans;private final IrrigationRepo irrigation;private final SoilRepo soil;public FarmController(FarmRepo f,FarmerRepo u,CropRepo c,ScanRepo s,IrrigationRepo i,SoilRepo m){farms=f;farmers=u;crops=c;scans=s;irrigation=i;soil=m;}
 private Long user(String h){Long id=Sessions.user(h);if(id==null)throw new ResponseStatusException(HttpStatus.UNAUTHORIZED,"Bearer token required");return id;}
 private Map<String,Object> view(Farm f){return Map.of("id",f.id,"name",f.name,"location",f.location,"area",f.area);}
 @GetMapping public List<Map<String,Object>> all(@RequestHeader(value="Authorization",required=false)String h){return farms.findByOwnerId(user(h)).stream().map(this::view).toList();}
 @PostMapping public ResponseEntity<?> create(@RequestHeader(value="Authorization",required=false)String h,@Valid @RequestBody FarmInput in){Farm f=new Farm();f.owner=farmers.findById(user(h)).orElseThrow();f.name=in.name();f.location=in.location();f.area=in.area();return ResponseEntity.status(201).body(view(farms.save(f)));}
 @GetMapping("/{id}") public Map<String,Object> get(@RequestHeader(value="Authorization",required=false)String h,@PathVariable Long id){return farms.findByIdAndOwnerId(id,user(h)).map(this::view).orElseThrow(()->new ResponseStatusException(HttpStatus.NOT_FOUND));}
 @PutMapping("/{id}") public Map<String,Object> update(@RequestHeader(value="Authorization",required=false)String h,@PathVariable Long id,@Valid @RequestBody FarmInput in){Farm f=farms.findByIdAndOwnerId(id,user(h)).orElseThrow(()->new ResponseStatusException(HttpStatus.NOT_FOUND));f.name=in.name();f.location=in.location();f.area=in.area();return view(farms.save(f));}
 @DeleteMapping("/{id}") public ResponseEntity<?> delete(@RequestHeader(value="Authorization",required=false)String h,@PathVariable Long id){Farm f=farms.findByIdAndOwnerId(id,user(h)).orElseThrow(()->new ResponseStatusException(HttpStatus.NOT_FOUND));for(Crop c:crops.findByFarmIdAndFarmOwnerId(id,user(h))){scans.deleteAll(scans.findByCropIdAndCropFarmOwnerIdOrderByScanDateDesc(c.id,user(h)));irrigation.deleteAll(irrigation.findByCropIdAndCropFarmOwnerIdOrderByIrrigationDateDesc(c.id,user(h)));soil.deleteAll(soil.findByCropIdAndCropFarmOwnerIdOrderByMeasurementDateDesc(c.id,user(h)));crops.delete(c);}farms.delete(f);return ResponseEntity.noContent().build();}
}



