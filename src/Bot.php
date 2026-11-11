
<?php

class Bot
{
    private $db;
    private $telegram;
    private $registration;

    public function __construct(PDO $db, Telegram $telegram)
    {
        $this->db = $db;
        $this->telegram = $telegram;
        $this->registration = new Registration($db);
    }

    public function handle($update)
    {
        if (!isset($update['update_id'])) {
            return;
        }

        $message = $update['message'] ?? null;

        // We only support private conversations.
        if (!$message || ($message['chat']['type'] ?? '') !== 'private') {
            return;
        }

        $chatId = $message['chat']['id'];
        $from = $message['from'] ?? [];

        if (empty($from['id'])) {
            return;
        }

        $this->db->beginTransaction();

        try {
            // Prevent processing the same Telegram update twice.
            $stmt = $this->db->prepare(
                "INSERT INTO processed_updates (update_id) VALUES (?)"
            );

            $stmt->execute([(string)$update['update_id']]);

            $response = null;
            $showKeyboard = false;

            $text = trim($message['text'] ?? '');

            if (preg_match('/^\/start(?:@\w+)?(?:\s|$)/i', $text)) {

                $response =
                    "Welcome to our platform! 👋\n\n" .
                    "We are happy to have you here.\n\n" .
                    "To create your account, please share your phone number using the button below.";

                $showKeyboard = true;

            } elseif (isset($message['contact'])) {

                $result = $this->registration->register(
                    $message['contact'],
                    $from
                );

                $response = $result['message'];

                if ($result['status'] === 'created') {
                    $response =
                        "🎉 Registration successful!\n\n" .
                        "Your account has been created.\n\n" .
                        "Name: " . ($from['first_name'] ?? '') . "\n" .
                        "Phone: " . $message['contact']['phone_number'] . "\n\n" .
                        "Welcome aboard!";
                }

                if ($result['status'] === 'existing') {
                    $response =
                        "👋 Welcome back!\n\n" .
                        "Your account is already registered.\n" .
                        "You can continue using our services.";
                }

                // Only successful registrations remove the keyboard.
                $showKeyboard = in_array(
                    $result['status'],
                    ['created', 'existing'],
                    true
                );

            } else {

                $response =
                    "Please use the button below to share your own phone number and complete registration.";

                $showKeyboard = true;
            }

            $this->db->commit();

            // Send response after database commit.
            if ($showKeyboard) {
                if (
                    isset($message['contact']) &&
                    in_array(
                        $result['status'] ?? '',
                        ['created', 'existing'],
                        true
                    )
                ) {
                    $this->telegram->removeKeyboard($chatId, $response);
                } else {
                    $this->telegram->showContactButton($chatId, $response);
                }
            } else {
                $this->telegram->sendMessage($chatId, $response);
            }

        } catch (PDOException $e) {

            if ($this->db->inTransaction()) {
                $this->db->rollBack();
            }

            // Duplicate update means Telegram already delivered it.
            if ($e->getCode() === '23000') {
                return;
            }

            throw $e;

        } catch (Throwable $e) {

            if ($this->db->inTransaction()) {
                $this->db->rollBack();
            }

            throw $e;
        }
    }
}
