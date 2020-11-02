package com.ibm.sample;

import java.io.*;
import java.util.*;
import javax.servlet.*;
import javax.servlet.annotation.*;
import javax.servlet.http.*;

@WebServlet(name = "Servlet1", urlPatterns = "/servlet1")
public class Servlet1 extends HttpServlet {
  @Override
  public void service(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
    PrintWriter out = response.getWriter();
    response.setContentType("text/plain");
    out.println("Hello World @ " + new Date());
  }
}
