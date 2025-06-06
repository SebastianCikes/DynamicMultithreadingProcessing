import java.awt.*; //<>//

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
  surface.setResizable(true);  // Permetti il ridimensionamento
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

  /*
  // Imposta il refresh rate in base allo schermo, se non lo riconosce imposta 60 FPS
   GraphicsEnvironment ge = GraphicsEnvironment.getLocalGraphicsEnvironment();
   GraphicsDevice[] gs = ge.getScreenDevices();
   for (int i = 0; i < gs.length; i++) {
   DisplayMode dm = gs[i].getDisplayMode();
   refreshRate = dm.getRefreshRate();
   if (refreshRate == DisplayMode.REFRESH_RATE_UNKNOWN) {
   refreshRate = 60;
   }
   }
   */

  frameRate(refreshRate);

  println("Avvio sistema...\n");

  int numThreads = runtime.availableProcessors();
  println("Numero di thread disponibili: " + numThreads);

  // Crea un bus di comunicazione per i thread
  // In realtà è solo una hash map
  bus = new DataBus();

  // Carica la configurazione base del programma
  JSONObject config = loadJSONObject("config.json");

  // Imposta il numero massimo di thread da utilizzare
  int maxThreads = config.getInt("maxThreads", 2);
  if (maxThreads <= 0 || maxThreads > numThreads) {
    maxThreads = numThreads;
  }
  println("Numero di thread massimi utilizzabili: " + maxThreads);
  println();

  // Crea uno scheduler
  // In realtà abbina i servizi ad un thread
  scheduler = new ServiceScheduler(maxThreads); // Assign to global scheduler
  
  // Più canvas assieme (windowDebug)
  if (config.getBoolean("debugMode")) {
    DebugWindow second = new DebugWindow(scheduler);
  }
  
  // Servizi da attivare
  println("Caricamento servizi...\n");
  JSONObject servicesConfig = config.getJSONObject("services");

  // ParserService
  if (servicesConfig.hasKey("ParserService")) {
    JSONObject serviceCfg = servicesConfig.getJSONObject("ParserService");
    if (serviceCfg.getBoolean("enabled", false)) {
      parser = new ParserService(bus); // 'parser' variable is already declared globally
      int preferredThread = serviceCfg.getInt("thread", -1); // -1 indicates no preference
      scheduler.addService(parser, preferredThread);
      println("ParserService caricato. Abilitato: true. Preferenza Thread: " + (preferredThread == -1 ? "Nessuna" : preferredThread) + "\n");
    } else {
      println("ParserService NON caricato. Abilitato: false.\n");
    }
  }

  // ReportingService
  if (servicesConfig.hasKey("ReportingService")) {
    JSONObject serviceCfg = servicesConfig.getJSONObject("ReportingService");
    if (serviceCfg.getBoolean("enabled", false)) {
      ReportingService reportingService = new ReportingService(bus); // Assuming constructor
      int preferredThread = serviceCfg.getInt("thread", -1);
      scheduler.addService(reportingService, preferredThread);
      println("ReportingService caricato. Abilitato: true. Preferenza Thread: " + (preferredThread == -1 ? "Nessuna" : preferredThread) + "\n");
    } else {
      println("ReportingService NON caricato. Abilitato: false.\n");
    }
  }

  // DataAggregatorService
  if (servicesConfig.hasKey("DataAggregatorService")) {
    JSONObject serviceCfg = servicesConfig.getJSONObject("DataAggregatorService");
    if (serviceCfg.getBoolean("enabled", false)) {
      DataAggregatorService dataAggregatorService = new DataAggregatorService(bus); // Assuming constructor
      int preferredThread = serviceCfg.getInt("thread", -1);
      scheduler.addService(dataAggregatorService, preferredThread);
      println("DataAggregatorService caricato. Abilitato: true. Preferenza Thread: " + (preferredThread == -1 ? "Nessuna" : preferredThread) + "\n");
    } else {
      println("DataAggregatorService NON caricato. Abilitato: false.\n");
    }
  }

  // NotificationService
  if (servicesConfig.hasKey("NotificationService")) {
    JSONObject serviceCfg = servicesConfig.getJSONObject("NotificationService");
    if (serviceCfg.getBoolean("enabled", false)) {
      NotificationService notificationService = new NotificationService(bus); // Assuming constructor
      int preferredThread = serviceCfg.getInt("thread", -1);
      scheduler.addService(notificationService, preferredThread);
      println("NotificationService caricato. Abilitato: true. Preferenza Thread: " + (preferredThread == -1 ? "Nessuna" : preferredThread) + "\n");
    } else {
      println("NotificationService NON caricato. Abilitato: false.\n");
    }
  }

  // LegacyService (example, remains disabled as per config)
  if (servicesConfig.hasKey("LegacyService")) {
    JSONObject serviceCfg = servicesConfig.getJSONObject("LegacyService");
    if (serviceCfg.getBoolean("enabled", false)) {
      // LegacyService legacyService = new LegacyService(bus); // Assuming constructor
      // int preferredThread = serviceCfg.getInt("thread", -1);
      // scheduler.addService(legacyService, preferredThread);
      // println("LegacyService caricato. Abilitato: true. Preferenza Thread: " + (preferredThread == -1 ? "Nessuna" : preferredThread));
    } else {
      // Add a print statement for services that are configured but not enabled
      println("LegacyService NON caricato. Abilitato: false.\n");
    }
  }

  scheduler.startAll();
}

void draw() {
  
  // Da qui in poi grafica
  
}
