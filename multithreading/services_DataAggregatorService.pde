class DataAggregatorService extends BaseService {
  DataBus bus;
  DataAggregatorService(DataBus bus) { this.bus = bus; }
  void setup() { println("DataAggregatorService setup."); }
  void loop() { /* Aggregation logic */ }
}
