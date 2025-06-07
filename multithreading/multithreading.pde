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
}

void setupDummyReferences() {
  // Questi riferimenti forzano la compilazione senza eseguire nulla
  if (false) {
    new ParserService(null, 10); // Updated for new constructor
    new TestService(null, 10); // Add dummy reference for TestService
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
        BaseService serviceInstance = createServiceInstance(serviceName, bus, loopDelay); // Pass loopDelay
        if (serviceInstance != null) {
          int preferredThread = serviceCfg.getInt("thread", -1); // -1 = nessuna preferenza
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

BaseService createServiceInstance(String serviceName, DataBus bus, int loopDelay) { // Added loopDelay parameter
  // Prova prima la reflection (per compatibilità futura)
  try {
    Class<?> serviceClass = Class.forName(serviceName);
    // Look for constructor with DataBus and int (for loopDelay)
    Constructor<?> constructor = serviceClass.getDeclaredConstructor(DataBus.class, int.class);
    return (BaseService) constructor.newInstance(bus, loopDelay); // Pass loopDelay
  }
  catch (Exception e) {
    // Reflection fallita, usa factory manuale
     println("Reflection failed for " + serviceName + ", attempting manual creation. Error: " + e.getMessage());
  }

  // Factory manuale come fallback affidabile
  return createServiceManually(serviceName, bus, loopDelay); // Pass loopDelay
}

BaseService createServiceManually(String serviceName, DataBus bus, int loopDelay) { // Added loopDelay parameter
  switch (serviceName) {
    case "ParserService":
      return new ParserService(bus, loopDelay); // Pass loopDelay
    case "TestService": // Add TestService case
      return new TestService(bus, loopDelay); // Pass loopDelay
    default:
      println("ERRORE: Servizio sconosciuto: " + serviceName);
    return null;
  }
}

void draw() {
  // Qui puoi aggiungere logica grafica se serve
}
