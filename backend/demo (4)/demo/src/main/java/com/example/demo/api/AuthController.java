package com.example.demo.api;
import com.example.demo.model.Farmer; import com.example.demo.repo.FarmerRepo; import com.example.demo.security.Sessions;
import jakarta.validation.Valid; import jakarta.validation.constraints.*; import org.springframework.http.*; import org.springframework.web.bind.annotation.*; import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder; import java.util.*;
@RestController @RequestMapping("/api/auth") public class AuthController {
 public record Register(@NotBlank String fullName,@Email @NotBlank String email,@NotBlank @Size(min=8) String password){} public record Login(@Email @NotBlank String email,@NotBlank String password){}
 private final FarmerRepo repo; private final BCryptPasswordEncoder encoder=new BCryptPasswordEncoder(); public AuthController(FarmerRepo r){repo=r;}
 @PostMapping("/register") public ResponseEntity<?> register(@Valid @RequestBody Register req){if(repo.findByEmail(req.email()).isPresent())return ResponseEntity.status(409).body(Map.of("error","Email already registered"));Farmer f=new Farmer();f.fullName=req.fullName();f.email=req.email().toLowerCase();f.passwordHash=encoder.encode(req.password());repo.save(f);return ResponseEntity.status(201).body(issue(f));}
 @PostMapping("/login") public ResponseEntity<?> login(@Valid @RequestBody Login req){return repo.findByEmail(req.email().toLowerCase()).filter(f->encoder.matches(req.password(),f.passwordHash)).<ResponseEntity<?>>map(f->ResponseEntity.ok(issue(f))).orElseGet(()->ResponseEntity.status(401).body(Map.of("error","Invalid email or password")));}
 private Map<String,Object> issue(Farmer f){String token=UUID.randomUUID().toString();Sessions.TOKENS.put(token,f.id);return Map.of("token",token,"user",Map.of("id",f.id,"fullName",f.fullName,"email",f.email));}
}



