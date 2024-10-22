<?php

require 'vendor/autoload.php';

use Kreait\Firebase\Factory;
use Kreait\Firebase\Messaging\CloudMessage;

$factory = (new Factory)->withServiceAccount('firebase_credentials.json');
$messaging = $factory->createMessaging();

// Define the API endpoint
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    // Get the JSON data from the request body
    $data = json_decode(file_get_contents('php://input'), true);

    // Extract battery level, state, and device ID from the request
    $batteryLevel = $data['batteryLevel'] ?? null;
    $batteryState = $data['batteryState'] ?? null;
    $deviceId = $data['deviceId'] ?? null;

    // Log the received data (optional)
    error_log("Device ID: $deviceId - Battery Level: $batteryLevel, State: $batteryState");

    // Check battery conditions and send notifications accordingly
    if ($batteryLevel !== null) {
        // Define the notification title and body based on battery state
        switch ($batteryState) {
            case 'charging':
                $title = 'Battery Charging';
                $body = "Your battery is charging. Current level: $batteryLevel%.";
                break;

            case 'discharging':
                if ($batteryLevel < 20) {
                    $title = 'Low Battery';
                    $body = "Your battery is low at $batteryLevel%. Please charge soon.";
                }
                break;

            case 'full':
                $title = 'Battery Full';
                $body = "Your battery is fully charged at 100%.";
                break;

            case 'connecting':
                if ($batteryLevel < 100) {
                    $title = 'Charging Connected';
                    $body = "Your device is connected to a charger but not fully charged. Current level: $batteryLevel%.";
                }
                break;

            case 'not charging':
                $title = 'Not Charging';
                $body = "Your device is not charging. Current battery level: $batteryLevel%.";
                break;

            default:
                $title = 'Battery Status';
                $body = "Current battery level: $batteryLevel%.";
                break;
        }

        // Send notification if applicable
        if (isset($title) && isset($body)) {
            sendFcmNotification($messaging, $deviceId, $title, $body);
        }
    }

    // Return a response
    header('Content-Type: application/json');
    echo json_encode(['status' => 'success']);
} else {
    // If not a POST request, return a 405 Method Not Allowed
    http_response_code(405);
    echo json_encode(['error' => 'Method Not Allowed']);
}

// Function to send FCM notification
function sendFcmNotification($messaging, $deviceId, $title, $body) {
    $message = CloudMessage::withTarget('token', $deviceId)
        ->withNotification(['title' => $title, 'body' => $body]);

    try {
        $messaging->send($message);
        error_log('Successfully sent notification to ' . $deviceId);
    } catch (\Kreait\Firebase\Exception\MessagingException $e) {
        error_log('Error sending FCM notification: ' . $e->getMessage());
    }
}
