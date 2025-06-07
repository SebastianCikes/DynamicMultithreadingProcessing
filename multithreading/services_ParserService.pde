class ParserService extends BaseService {
  DataBus bus;

  ParserService(DataBus bus, int loopDelay) { // Added loopDelay parameter
    super(loopDelay); // Call super constructor
    this.bus = bus;
    /*
    // Intentionally throw an error to test constructor exception handling
    if (true) { 
      throw new RuntimeException("Test error triggered in ParserService constructor for dynamic loading test.");
    }*/
    
  }

  void setup() {
    // inizializzazione se necessaria
  }

  void loop() {
    println("ParserService running...");
    String raw = bus.get("RAW_DATA");
    if (raw != null && raw.startsWith("DATA_")) {
      String parsed = "Elaborato: " + raw.split("_")[1];
      bus.put("PARSED_DATA", parsed);
    }
  }
}
