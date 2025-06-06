class ParserService extends BaseService {
  // Elaborazione dati in ingresso
  
  DataBus bus;

  ParserService(DataBus bus) {
    this.bus = bus;
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
