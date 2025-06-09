import java.io.FileInputStream;
import java.io.DataInputStream;
import java.io.EOFException;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.Date; // For formatting timestamp
import java.text.SimpleDateFormat; // For formatting timestamp

void setup() {
  size(400, 200); // Set a screen size
  println("Starting log decoding...");
  decodeLogs(sketchPath("../multithreading/data/log/application.log"));
  println("Log decoding finished.");
  noLoop(); // This is a one-off utility
}

void decodeLogs(String filename) {
  DataInputStream dis = null;
  SimpleDateFormat sdf = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS");

  try {
    dis = new DataInputStream(new FileInputStream(filename));
    println("Decoding logs from: " + filename + "\n");

    while (true) { // Loop indefinitely until EOFException
      long timestamp = dis.readLong();
      long threadId = dis.readLong();

      int messageTypeLength = dis.readInt();
      byte[] messageTypeBytes = new byte[messageTypeLength];
      dis.readFully(messageTypeBytes);
      String messageType = new String(messageTypeBytes, StandardCharsets.UTF_8);

      int messageContentLength = dis.readInt();
      byte[] messageContentBytes = new byte[messageContentLength];
      dis.readFully(messageContentBytes);
      String messageContent = new String(messageContentBytes, StandardCharsets.UTF_8);

      String formattedTimestamp = sdf.format(new Date(timestamp));

      println("Timestamp: " + formattedTimestamp +
        ", ThreadID: " + threadId +
        ", Type: " + messageType +
        ", Content: " + messageContent);
    }
  }
  catch (EOFException e) {
    println("\nReached end of log file.");
  }
  catch (IOException e) {
    println("Error reading log file: " + e.getMessage());
    e.printStackTrace();
  }
  finally {
    if (dis != null) {
      try {
        dis.close();
      }
      catch (IOException e) {
        println("Error closing DataInputStream: " + e.getMessage());
      }
    }
  }
}

void draw() {
  // noLoop()
}
