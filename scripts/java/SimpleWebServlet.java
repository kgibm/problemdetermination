package com.ibm.simpleweb;

import java.io.IOException;
import java.io.PrintWriter;
import java.util.logging.Level;
import java.util.logging.Logger;

import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

@WebServlet("/SimpleWebServlet")
public class SimpleWebServlet extends HttpServlet {
	private static final long serialVersionUID = 1L;

	private final static String LOG_CLASS = SimpleWebServlet.class
			.getCanonicalName();
	private final static String LOG_METHOD_SERVICE = "service";

	private final static Logger log = Logger.getLogger(LOG_CLASS);

	protected void service(HttpServletRequest request,
			HttpServletResponse response) throws ServletException, IOException {
		if (log.isLoggable(Level.FINER))
			log.entering(LOG_CLASS, LOG_METHOD_SERVICE);

		response.setContentType("text/plain");
		PrintWriter out = response.getWriter();
		out.println("Hello World");

		if (log.isLoggable(Level.FINER))
			log.exiting(LOG_CLASS, LOG_METHOD_SERVICE);
	}
}
