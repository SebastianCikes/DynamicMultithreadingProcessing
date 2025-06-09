import java.io.FileOutputStream;
import java.io.DataOutputStream;
import java.io.IOException;
import java.nio.charset.StandardCharsets;

import java.io.FileOutputStream;
import java.io.DataOutputStream;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList; // Added for pendingMessages
import java.io.File; // Added for File operations

class LoggingService extends BaseService {
  private DataOutputStream logOutput;
  private ArrayList<BaseMessage> pendingMessages = new ArrayList<BaseMessage>();
  private boolean setupCompleted = false;
  private boolean setupSucceeded = false;
  private String logFilePath;

  public LoggingService(ServiceScheduler scheduler, int loopDelay, String logFilePathString) {
    super(scheduler, loopDelay);
    // Store the raw path; resolution will happen in setup()
    this.logFilePath = logFilePathString; 
    if (this.logFilePath == null || this.logFilePath.isEmpty()) {
      this.logFilePath = "default_application.log";
      println("LoggingService Warning: No log file path provided or path was empty, defaulting to '" + this.logFilePath + "'");
    }
  }

  @Override
  void setup() {
    setupCompleted = true; // Mark that setup process has started
    String actualLogPath = this.logFilePath; // Start with the configured path

    try {
        File tempFile = new File(this.logFilePath);
        if (!tempFile.isAbsolute()) {
            // If the path is not absolute, make it relative to the sketch's data path.
            actualLogPath = dataPath(this.logFilePath); 
            println("LoggingService: Relative log path '" + this.logFilePath + "' provided. Resolved to data directory: " + actualLogPath);
        }

        File logFile = new File(actualLogPath); // Use the potentially modified path
        File parentDir = logFile.getParentFile();
        if (parentDir != null && !parentDir.exists()) {
            if (parentDir.mkdirs()) {
                println("LoggingService: Created parent directory for log file: " + parentDir.getAbsolutePath());
            } else {
                // Check again in case of a race condition where another thread created it
                if (!parentDir.exists()) {
                    println("LoggingService Error: Failed to create parent directory: " + parentDir.getAbsolutePath() + ". Logging will likely fail.");
                    // This situation will lead to an IOException when trying to create FileOutputStream if path is invalid.
                }
            }
        }

        logOutput = new DataOutputStream(new FileOutputStream(logFile)); // Use logFile here
        setupSucceeded = true;
        println("LoggingService Started. Logging to " + actualLogPath + ". Ready to receive messages on thread " + Thread.currentThread().getName() + " (ID: " + Thread.currentThread().getId() + ")");

        // Process pending messages
        ArrayList<BaseMessage> messagesToProcess = new ArrayList<BaseMessage>(pendingMessages);
        pendingMessages.clear();
        for (BaseMessage msg : messagesToProcess) {
            writeBinaryLogInternal(msg); // Assumes writeBinaryLogInternal handles logOutput correctly
        }
        if (messagesToProcess.size() > 0) {
          println("LoggingService: Processed " + messagesToProcess.size() + " pending messages.");
        }

    } catch (IOException e) {
        setupSucceeded = false;
        println("Error initializing LoggingService with file '" + actualLogPath + "': " + e.getMessage() + ". Pending messages will be dropped.");
        pendingMessages.clear(); // Clear pending messages as setup failed
    }
  }

  @Override
    void processMessage(BaseMessage message) {
    if (message == null) {
      println("LoggingService received a null message.");
      return;
    }

    if (!setupCompleted) {
      pendingMessages.add(message);
      // println("LoggingService setup not complete. Queuing message: " + messageToString(message)); // Optional: for debugging
      return;
    }

    if (setupCompleted && !setupSucceeded) {
      println("LoggingService setup failed. Dropping message: " + messageToString(message));
      return;
    }

    // If setupCompleted and setupSucceeded are both true
    writeBinaryLogInternal(message);

    // Example of how LoggingService could forward or react (not part of this subtask)
    // if (message instanceof RawDataMessage && ((RawDataMessage)message).payload.contains("CRITICAL")) {
    //   BaseMessage alert = new BaseMessage(); // Simplified, would be specific alert type
    //   this.scheduler.sendMessageToService("AlertService", alert);
    // }
  }

  private String messageToString(BaseMessage msg) {
    if (msg instanceof RawDataMessage) {
      return "RawDataMessage(payload='" + ((RawDataMessage)msg).payload + "')";
    } else if (msg instanceof ParsedDataMessage) {
      return "ParsedDataMessage(parsedContent='" + ((ParsedDataMessage)msg).parsedContent + "')";
    }
    // Add more types as they are created, e.g.:
    // else if (msg instanceof SystemStatusMessage) {
    //   return "SystemStatusMessage(status='" + ((SystemStatusMessage)msg).status + "')";
    // }
    return "Generic BaseMessage (specific content not displayed by LoggingService.messageToString)";
  }

  private void writeBinaryLogInternal(BaseMessage message) {
    if (!setupSucceeded || logOutput == null) {
      // This case should ideally not be hit if processMessage logic is correct
      println("Internal error: writeBinaryLogInternal called when setup failed or logOutput is null. Message: " + messageToString(message));
      return;
    }
    try {
      logOutput.writeLong(message.timestamp);
      logOutput.writeLong(Thread.currentThread().getId());

      byte[] messageTypeBytes = message.messageType.getBytes(StandardCharsets.UTF_8);
      logOutput.writeInt(messageTypeBytes.length);
      logOutput.write(messageTypeBytes);

      String messageContent = messageToString(message);
      byte[] messageContentBytes = messageContent.getBytes(StandardCharsets.UTF_8);
      logOutput.writeInt(messageContentBytes.length);
      logOutput.write(messageContentBytes);

    } catch (IOException e) {
      println("Error writing binary log: " + e.getMessage());
      // Consider how to handle this - e.g., retry, log to console, or stop service
    }
  }

  // Call this method when the application is shutting down to ensure logs are flushed and resources released.
  public void dispose() {
    println("Closing log file stream in LoggingService.");
    if (logOutput != null) {
      try {
        logOutput.flush();
        logOutput.close();
      } catch (IOException e) {
        println("Error closing logOutput: " + e.getMessage());
      }
    }
  }
}
