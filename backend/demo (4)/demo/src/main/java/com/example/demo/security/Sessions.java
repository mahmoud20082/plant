package com.example.demo.security;
import com.example.demo.model.Farmer; import java.util.*; import java.util.concurrent.*;
public final class Sessions { private Sessions(){} public static final Map<String,Long> TOKENS=new ConcurrentHashMap<>(); public static Long user(String token){if(token==null)return null;return TOKENS.get(token.replaceFirst("(?i)^Bearer\\s+",""));} }
