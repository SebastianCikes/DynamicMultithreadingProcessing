class ParserService extends BaseService {
  DataBus bus;

  ParserService(DataBus bus) {
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
    String raw = bus.get("RAW_DATA");
    if (raw != null && raw.startsWith("DATA_")) {
      String parsed = "Elaborato: " + raw.split("_")[1];
      bus.put("PARSED_DATA", parsed);
    }
  }
}
