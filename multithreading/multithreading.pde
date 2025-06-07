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
  try {
    Class<?> serviceClass = Class.forName(serviceName);
    Constructor<?> constructor;
    BaseService instance;

    try {
      // Try constructor with (DataBus, ServiceScheduler, int)
      constructor = serviceClass.getDeclaredConstructor(DataBus.class, ServiceScheduler.class, int.class);
      instance = (BaseService) constructor.newInstance(bus, scheduler, loopDelay);
      println("Service " + serviceName + " instantiated using (DataBus, ServiceScheduler, int) constructor.");
      return instance;
    }
    catch (NoSuchMethodException nsme1) {
      // If not found, try constructor with (ServiceScheduler, int)
      try {
        constructor = serviceClass.getDeclaredConstructor(ServiceScheduler.class, int.class);
        instance = (BaseService) constructor.newInstance(scheduler, loopDelay);
        println("Service " + serviceName + " instantiated using (ServiceScheduler, int) constructor.");
        return instance;
      }
      catch (NoSuchMethodException nsme2) {
        println("ERROR: No suitable constructor found for " + serviceName + ". Tried (DataBus, ServiceScheduler, int) and (ServiceScheduler, int).");
        // Fall through to manual creation
      }
    }
  }
  catch (Exception e) {
    println("ERROR: General exception during reflection for " + serviceName + ": " + e.getMessage());
    // Fall through to manual creation
  }

  println("Attempting manual creation for " + serviceName + " due to reflection issue or constructor mismatch.");
  // Pass scheduler to manual creation as well
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
