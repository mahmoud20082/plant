package com.example.demo.api;
import org.springframework.http.*;import org.springframework.web.bind.annotation.*;import org.springframework.web.multipart.MaxUploadSizeExceededException;import java.util.*;
@RestControllerAdvice public class ApiErrors{
 @ExceptionHandler(MaxUploadSizeExceededException.class) public ResponseEntity<?> tooLarge(Exception e){return ResponseEntity.badRequest().body(Map.of("error","Image exceeds the 10 MB upload limit"));}
 @ExceptionHandler(org.springframework.web.bind.MethodArgumentNotValidException.class) public ResponseEntity<?> invalid(org.springframework.web.bind.MethodArgumentNotValidException e){return ResponseEntity.badRequest().body(Map.of("error","Validation failed","details",e.getBindingResult().getFieldErrors().stream().map(x->x.getField()+": "+x.getDefaultMessage()).toList()));}
}


