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
  // Ottieni il frame in modo sicuro
  Component comp = (Component) surface.getNative();
  while (comp != null && !(comp instanceof Frame)) {
    comp = comp.getParent();
  }
  if (comp != null) {
    frame = (Frame) comp;
  } else {
    println("Frame non trovato.");
  }

  frameRate(refreshRate);
  println("Avvio sistema...\n");

  int numThreads = runtime.availableProcessors();
  println("Numero di thread disponibili: " + numThreads);

  bus = new DataBus();
  JSONObject config = loadJSONObject("config.json");
  int maxThreads = config.getInt("maxThreads", 2);
  if (maxThreads <= 0 || maxThreads > numThreads) {
    maxThreads = numThreads;
  }
  println("Numero di thread massimi utilizzabili: " + maxThreads);
  println();

  scheduler = new ServiceScheduler(maxThreads);

  if (config.getBoolean("debugMode")) {
    DebugWindow second = new DebugWindow(scheduler);
  }

  println("Inizio caricamento dinamico servizi...\n");
  loadDynamicServices(config);
  println("Fine caricamento dinamico servizi.\n");

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
  // Questi riferimenti forzano la compilazione senza eseguire nulla
  if (false) {
    // Pass null for scheduler in dummy references
    new ParserService(null, 10); 
    new TestService(null, null, 10);
    new LoggingService(null, 10); // Add dummy reference for LoggingService
  }
}

void loadDynamicServices(JSONObject config) {
  JSONObject servicesConfig = config.getJSONObject("services");
  if (servicesConfig != null) {
    Set<String> keys = servicesConfig.keys();
    for (String serviceName : keys) {
      JSONObject serviceCfg = servicesConfig.getJSONObject(serviceName);
      boolean isEnabled = serviceCfg.getBoolean("enabled", false);
      println("Configurazione per servizio: " + serviceName + " - Abilitato: " + isEnabled);

      if (isEnabled) {
        int loopDelay = serviceCfg.getInt("loopDelay", 10); // Read loopDelay, default to 10
        // Pass scheduler to createServiceInstance
        BaseService serviceInstance = createServiceInstance(serviceName, bus, scheduler, loopDelay); 
        if (serviceInstance != null) {
          int preferredThread = serviceCfg.getInt("thread", -1); // -1 = nessuna preferenza
          // scheduler.addService is already adding the service to its internal map
          scheduler.addService(serviceInstance, preferredThread); 
          println(serviceName + " caricato dinamicamente. Thread: " + (preferredThread == -1 ? "Nessuno" : preferredThread) + "\n");

          if (serviceName.equals("ParserService")) {
            parser = (ParserService) serviceInstance;
            println("ParserService assegnato alla variabile globale.\n");
          }
        } else {
          println("ERRORE: Impossibile creare istanza di " + serviceName + "\n");
        }
      } else {
        println(serviceName + " NON caricato (disabilitato nel config).\n");
      }
    }
  }
}

// Updated signature to include scheduler
BaseService createServiceInstance(String serviceName, DataBus bus, ServiceScheduler scheduler, int loopDelay) {
  Class<?> serviceClass = null;
  try { // Outer try for overall reflection process, including class loading and instantiation
    String sketchClassName = getClass().getName(); // Get the main sketch's class name
    try {
      // Attempt to load as an inner class of the main sketch first
      serviceClass = Class.forName(sketchClassName + "$" + serviceName);
      println("INFO: Successfully loaded class " + serviceName + " as inner class: " + serviceClass.getName());
    } catch (ClassNotFoundException e) {
      println("INFO: Could not load " + serviceName + " as an inner class (" + sketchClassName + "$" + serviceName + "), trying as top-level class. Details: " + e.getMessage());
      try {
        // Fallback: attempt to load as a top-level class
        serviceClass = Class.forName(serviceName);
        println("INFO: Successfully loaded class " + serviceName + " as top-level class: " + serviceClass.getName());
      } catch (ClassNotFoundException e2) {
        println("ERROR: ClassNotFoundException for " + serviceName + " (tried as inner and top-level). Details: " + e2.getMessage());
        e2.printStackTrace(); // Print stack trace for the final ClassNotFoundException
        // If class not found, cannot proceed with reflection. Directly use manual creation.
        println("Attempting manual creation for " + serviceName + " (class not found via reflection).");
        return createServiceManually(serviceName, bus, scheduler, loopDelay);
      }
    }

    // If serviceClass is loaded successfully, proceed with constructor lookup and instantiation...
    Constructor<?> constructor;
    BaseService instance;
    Class<?> outerClassType = this.getClass(); // Class of the main sketch (e.g., multithreading)

    // This block attempts to instantiate assuming serviceClass might be a non-static inner class
    try { 
      // Try constructor with (Outer, DataBus, ServiceScheduler, int)
      constructor = serviceClass.getDeclaredConstructor(outerClassType, DataBus.class, ServiceScheduler.class, int.class);
      instance = (BaseService) constructor.newInstance(this, bus, scheduler, loopDelay); // 'this' is the first argument
      println("Service " + serviceName + " instantiated via reflection using (Outer, DataBus, ServiceScheduler, int) constructor.");
      return instance;
    } catch (NoSuchMethodException nsme1) {
      // If not found, try constructor with (Outer, ServiceScheduler, int)
      try {
        constructor = serviceClass.getDeclaredConstructor(outerClassType, ServiceScheduler.class, int.class);
        instance = (BaseService) constructor.newInstance(this, scheduler, loopDelay); // 'this' is the first argument
        println("Service " + serviceName + " instantiated via reflection using (Outer, ServiceScheduler, int) constructor.");
        return instance;
      } catch (NoSuchMethodException nsme2) {
        // These specific constructor forms for inner classes were not found.
        // This might be okay if the class is static or a top-level class,
        // in which case the original constructor search (without outerClassType) might be relevant.
        // However, Processing typically makes .pde classes non-static inner classes.
        // If these fail, it's a strong indication that manual creation or a different constructor signature is needed.
        println("INFO: Standard inner class constructor forms not found for " + serviceName + ". Tried (Outer,DataBus,SS,int) and (Outer,SS,int). Details: " + nsme2.getMessage());
        // nsme2.printStackTrace(); // This can be very verbose if this is a common path for static/top-level classes.
        // Let's proceed to try non-inner class forms if these fail.
      }
    }
    
    // Fallback to trying original constructor signatures (for static inner classes or top-level classes)
    // This part is kept from the previous version of the method.
    try { 
      // Try constructor with (DataBus, ServiceScheduler, int) - for static/top-level
      constructor = serviceClass.getDeclaredConstructor(DataBus.class, ServiceScheduler.class, int.class);
      instance = (BaseService) constructor.newInstance(bus, scheduler, loopDelay);
      println("Service " + serviceName + " instantiated via reflection using (DataBus, ServiceScheduler, int) constructor (likely static or top-level).");
      return instance;
    } catch (NoSuchMethodException nsme3) {
      // If not found, try constructor with (ServiceScheduler, int) - for static/top-level
      try {
        constructor = serviceClass.getDeclaredConstructor(ServiceScheduler.class, int.class);
        instance = (BaseService) constructor.newInstance(scheduler, loopDelay);
        println("Service " + serviceName + " instantiated via reflection using (ServiceScheduler, int) constructor (likely static or top-level).");
        return instance;
      } catch (NoSuchMethodException nsme4) {
        println("ERROR: No suitable constructor found for " + serviceName + " via reflection. All attempts failed (inner, static, top-level forms).");
        // nsme4.printStackTrace(); // Log the final NoSuchMethodException if desired
        // Fall through to manual creation at the end of the method
      }
    }
  } catch (Exception e) { // General catch-all for other reflection issues (e.g., InvocationTargetException, IllegalAccessException)
    // This catch handles exceptions from any of the reflection attempts above (inner class forms or static/top-level forms)
    println("ERROR: General exception during reflection for " + serviceName + " (after class loading, if successful): " + e.getMessage());
    e.printStackTrace();
    // Fall through to manual creation at the end of the method
  }

  // Fallback to manual creation if constructor lookup failed OR a general reflection exception occurred after class loading
  println("Attempting manual creation for " + serviceName + " (reflection for constructor failed or other general issue post-classloading).");
  return createServiceManually(serviceName, bus, scheduler, loopDelay);
}

// Updated signature to include scheduler
BaseService createServiceManually(String serviceName, DataBus bus, ServiceScheduler scheduler, int loopDelay) {
  switch (serviceName) {
    case "ParserService":
      return new ParserService(scheduler, loopDelay); // Pass scheduler
    case "TestService":
      return new TestService(bus, scheduler, loopDelay); // Pass scheduler
    case "LoggingService": // Add LoggingService case
      return new LoggingService(scheduler, loopDelay); // Pass scheduler
    default:
      println("ERRORE: Servizio sconosciuto: " + serviceName);
    return null;
  }
}

void draw() {
  // Qui puoi aggiungere logica grafica se serve
}
