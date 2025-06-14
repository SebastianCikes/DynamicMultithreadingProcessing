import java.awt.*;
import java.lang.reflect.Constructor;
import java.util.Set;

ParserService parser;
ServiceScheduler scheduler;
DataBus bus;
DebugMonitor monitor = new DebugMonitor(this);
Runtime runtime = Runtime.getRuntime();

int refreshRate = 60;
boolean isMaximized = false;

Frame frame;

void settings() {
  size(800, 600);
}

void setup() {
  setupDummyReferences();

  surface.setResizable(true);
  // Get the frame safely
  Component comp = (Component) surface.getNative();
  while (comp != null && !(comp instanceof Frame)) {
    comp = comp.getParent();
  }
  if (comp != null) {
    frame = (Frame) comp;
  } else {
    println("Frame not found.");
  }

  frameRate(refreshRate);
  println("Starting system...\n");

  int numThreads = runtime.availableProcessors();
  println("Number of available threads: " + numThreads);

  bus = new DataBus();
  JSONObject config = loadJSONObject("config.json");
  int maxThreads = config.getInt("maxThreads", 2);
  if (maxThreads <= 0 || maxThreads > numThreads) {
    maxThreads = numThreads;
  }
  println("Maximum number of usable threads: " + maxThreads);
  println();

  scheduler = new ServiceScheduler(maxThreads);

  if (config.getBoolean("debugMode")) {
    DebugWindow second = new DebugWindow(scheduler);
  }

  println("Starting dynamic loading of services...\n");
  loadDynamicServices(config);
  println("End of dynamic loading of services.\n");

  scheduler.startAll();

  // Test sending a message to ParserService
  BaseService parserInstance = scheduler.getService("ParserService");
  if (parserInstance != null) {
    println("Attempting to send a test message to ParserService...");
    RawDataMessage testMessage = new RawDataMessage("DATA_TestPayload123_FromSetup");
    parserInstance.inputQueue.enqueue(testMessage);
    println("Test message enqueued for ParserService.");
  } else {
    println("Could not find ParserService instance to send a test message.");
  }
}

void setupDummyReferences() {
  // These references force compilation without executing anything
  if (false) {
    // Pass null for scheduler in dummy references
    new ParserService(null, 10);
    new TestService(null, null, 10);
    new LoggingService(null, 10, "dummy_path.log"); // Add dummy reference for LoggingService
  }
}

void loadDynamicServices(JSONObject config) {
  JSONObject servicesConfig = config.getJSONObject("services");
  if (servicesConfig != null) {
    Set<String> keys = servicesConfig.keys();
    for (String serviceName : keys) {
      JSONObject serviceCfg = servicesConfig.getJSONObject(serviceName);
      boolean isEnabled = serviceCfg.getBoolean("enabled", false);
      println("Configuration for service: " + serviceName + " - Enabled: " + isEnabled);

      if (isEnabled) {
        int loopDelay = serviceCfg.getInt("loopDelay", 10); // Read loopDelay, default to 10
        String loggingFilePath = config.getString("loggingFilePath", "app_logs/default_app.log"); // Read from global config
        // Pass scheduler and loggingFilePath to createServiceInstance
        BaseService serviceInstance = createServiceInstance(serviceName, bus, scheduler, loopDelay, loggingFilePath);
        if (serviceInstance != null) {
          int preferredThread = serviceCfg.getInt("thread", -1); // -1 = no preference
          // scheduler.addService is already adding the service to its internal map
          scheduler.addService(serviceInstance, preferredThread);
          println(serviceName + " dynamically loaded. Thread: " + (preferredThread == -1 ? "None" : preferredThread) + "\n");

          if (serviceName.equals("ParserService")) {
            parser = (ParserService) serviceInstance;
            println("ParserService assigned to the global variable.\n");
          }
        } else {
          println("ERROR: Unable to create instance of " + serviceName + "\n");
        }
      } else {
        println(serviceName + " NOT loaded (disabled in config).\n");
      }
    }
  }
}

// Updated signature to include scheduler and loggingFilePath
BaseService createServiceInstance(String serviceName, DataBus bus, ServiceScheduler scheduler, int loopDelay, String loggingFilePath) {
  Class<?> serviceClass = null;
  try { // Outer try for overall reflection process, including class loading and instantiation
    String sketchClassName = getClass().getName(); // Get the main sketch's class name
    try {
      // Attempt to load as an inner class of the main sketch first
      serviceClass = Class.forName(sketchClassName + "$" + serviceName);
      println("INFO: Successfully loaded class " + serviceName + " as inner class: " + serviceClass.getName());
    }
    catch (ClassNotFoundException e) {
      println("INFO: Could not load " + serviceName + " as an inner class (" + sketchClassName + "$" + serviceName + "), trying as top-level class. Details: " + e.getMessage());
      try {
        // Fallback: attempt to load as a top-level class
        serviceClass = Class.forName(serviceName);
        println("INFO: Successfully loaded class " + serviceName + " as top-level class: " + serviceClass.getName());
      }
      catch (ClassNotFoundException e2) {
        println("ERROR: ClassNotFoundException for " + serviceName + " (tried as inner and top-level). Details: " + e2.getMessage());
        e2.printStackTrace(); // Print stack trace for the final ClassNotFoundException
        // If class not found, cannot proceed with reflection. Directly use manual creation.
        println("Attempting manual creation for " + serviceName + " (class not found via reflection).");
        return createServiceManually(serviceName, bus, scheduler, loopDelay, loggingFilePath); // Pass loggingFilePath
      }
    }

    // If serviceClass is loaded successfully, proceed with constructor lookup and instantiation...
    Constructor<?> constructor;
    BaseService instance;
    Class<?> outerClassType = this.getClass(); // Class of the main sketch (e.g., multithreading)

    // This block attempts to instantiate assuming serviceClass might be a non-static inner class
    try {
      // NEW: Try constructor for LoggingService (Outer, ServiceScheduler, int, String)
      if (serviceName.equals("LoggingService")) {
        constructor = serviceClass.getDeclaredConstructor(outerClassType, ServiceScheduler.class, int.class, String.class);
        instance = (BaseService) constructor.newInstance(this, scheduler, loopDelay, loggingFilePath);
        println("Service " + serviceName + " instantiated via reflection using (Outer, ServiceScheduler, int, String) constructor.");
        return instance;
      }
    } catch (NoSuchMethodException nsmeSpecific) {
        // This is fine, it just means it's not LoggingService with this specific new signature
        // Fall through to other attempts.
    }
    
    try {
      // Try constructor with (Outer, DataBus, ServiceScheduler, int)
      constructor = serviceClass.getDeclaredConstructor(outerClassType, DataBus.class, ServiceScheduler.class, int.class);
      instance = (BaseService) constructor.newInstance(this, bus, scheduler, loopDelay); // 'this' is the first argument
      println("Service " + serviceName + " instantiated via reflection using (Outer, DataBus, ServiceScheduler, int) constructor.");
      return instance;
    }
    catch (NoSuchMethodException nsme1) {
      // If not found, try constructor with (Outer, ServiceScheduler, int)
      try {
        constructor = serviceClass.getDeclaredConstructor(outerClassType, ServiceScheduler.class, int.class);
        instance = (BaseService) constructor.newInstance(this, scheduler, loopDelay); // 'this' is the first argument
        println("Service " + serviceName + " instantiated via reflection using (Outer, ServiceScheduler, int) constructor.");
        return instance;
      }
      catch (NoSuchMethodException nsme2) {
        println("INFO: Standard inner class constructor forms not found for " + serviceName + ". Tried (Outer,DataBus,SS,int) and (Outer,SS,int). Details: " + nsme2.getMessage());
      }
    }

    // Fallback to trying original constructor signatures (for static inner classes or top-level classes)
    try {
      // NEW: Try constructor for LoggingService (ServiceScheduler, int, String) - for static/top-level
      if (serviceName.equals("LoggingService")) {
          constructor = serviceClass.getDeclaredConstructor(ServiceScheduler.class, int.class, String.class);
          instance = (BaseService) constructor.newInstance(scheduler, loopDelay, loggingFilePath);
          println("Service " + serviceName + " instantiated via reflection using (ServiceScheduler, int, String) constructor (likely static or top-level).");
          return instance;
      }
    } catch (NoSuchMethodException nsmeSpecificStatic) {
        // Fine, fall through.
    }

    try {
      // Try constructor with (DataBus, ServiceScheduler, int) - for static/top-level
      constructor = serviceClass.getDeclaredConstructor(DataBus.class, ServiceScheduler.class, int.class);
      instance = (BaseService) constructor.newInstance(bus, scheduler, loopDelay);
      println("Service " + serviceName + " instantiated via reflection using (DataBus, ServiceScheduler, int) constructor (likely static or top-level).");
      return instance;
    }
    catch (NoSuchMethodException nsme3) {
      // If not found, try constructor with (ServiceScheduler, int) - for static/top-level
      try {
        constructor = serviceClass.getDeclaredConstructor(ServiceScheduler.class, int.class);
        instance = (BaseService) constructor.newInstance(scheduler, loopDelay);
        println("Service " + serviceName + " instantiated via reflection using (ServiceScheduler, int) constructor (likely static or top-level).");
        return instance;
      }
      catch (NoSuchMethodException nsme4) {
        println("ERROR: No suitable constructor found for " + serviceName + " via reflection. All attempts failed (inner, static, top-level forms).");
      }
    }
  }
  catch (Exception e) { // General catch-all for other reflection issues
    println("ERROR: General exception during reflection for " + serviceName + " (after class loading, if successful): " + e.getMessage());
    e.printStackTrace();
  }

  // Fallback to manual creation
  println("Attempting manual creation for " + serviceName + " (reflection failed or other issue).");
  return createServiceManually(serviceName, bus, scheduler, loopDelay, loggingFilePath); // Pass loggingFilePath
}

// Updated signature to include scheduler and loggingFilePath
BaseService createServiceManually(String serviceName, DataBus bus, ServiceScheduler scheduler, int loopDelay, String loggingFilePath) {
  switch (serviceName) {
    case "ParserService":
      return new ParserService(scheduler, loopDelay);
    case "TestService":
      return new TestService(bus, scheduler, loopDelay);
    case "LoggingService":
      return new LoggingService(scheduler, loopDelay, loggingFilePath); // Pass loggingFilePath
  default:
    println("ERROR: Unknown service: " + serviceName);
    return null;
  }
}

void draw() {
  // Here you can add graphic logic if needed
}
