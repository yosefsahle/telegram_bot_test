
<?php

class Telegram
{
    private $token;
    private $apiUrl;

    public function __construct($token)
    {
        $this->token = $token;
        $this->apiUrl = "https://api.telegram.org/bot" . $token . "/";
    }

    public function request($method, $data = [])
    {
        $ch = curl_init($this->apiUrl . $method);

        curl_setopt_array($ch, [
            CURLOPT_POST => true,
            CURLOPT_POSTFIELDS => json_encode($data),
            CURLOPT_HTTPHEADER => [
                'Content-Type: application/json'
            ],
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_CONNECTTIMEOUT => 10,
            CURLOPT_TIMEOUT => 20
        ]);

        $response = curl_exec($ch);
        $error = curl_error($ch);
        $status = curl_getinfo($ch, CURLINFO_HTTP_CODE);

        curl_close($ch);

        if ($response === false) {
            throw new RuntimeException("Telegram API error: " . $error);
        }

        $result = json_decode($response, true);

        if ($status < 200 || $status >= 300 || !($result['ok'] ?? false)) {
            throw new RuntimeException(
                "Telegram API request failed: " . $response
            );
        }

        return $result['result'];
    }

    public function sendMessage($chatId, $text, $keyboard = null)
    {
        $data = [
            'chat_id' => $chatId,
            'text' => $text
        ];

        if ($keyboard !== null) {
            $data['reply_markup'] = $keyboard;
        }

        return $this->request('sendMessage', $data);
    }

    public function showContactButton($chatId, $text = null)
{
    return $this->sendMessage(
        $chatId,
        $text ?? "Welcome! Please share your phone number.",
        [
            'keyboard' => [
                [
                    [
                        'text' => '📱 Share My Phone Number',
                        'request_contact' => true
                    ]
                ]
            ],
            'resize_keyboard' => true,
            'one_time_keyboard' => true
        ]
    );
}

    public function removeKeyboard($chatId, $text)
    {
        return $this->sendMessage(
            $chatId,
            $text,
            [
                'remove_keyboard' => true
            ]
        );
    }
}
