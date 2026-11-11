
<?php

class Registration
{
    private $db;

    public function __construct(PDO $db)
    {
        $this->db = $db;
    }

    private function normalizePhone($phone)
    {
        // Remove spaces, brackets, dashes and other formatting.
        $phone = preg_replace('/[\s().-]+/', '', trim($phone));

        // Convert international dialing prefix 00 to +.
        if (str_starts_with($phone, '00')) {
            $phone = '+' . substr($phone, 2);
        }

        // Telegram normally supplies an international number.
        if (!str_starts_with($phone, '+')) {
            $phone = '+' . $phone;
        }

        if (!preg_match('/^\+[1-9][0-9]{6,14}$/', $phone)) {
            throw new InvalidArgumentException(
                'Invalid phone number format.'
            );
        }

        return $phone;
    }

    public function register($contact, $telegramUser)
    {
        $telegramId = (string)($telegramUser['id'] ?? '');

        if (
            $telegramId === '' ||
            !ctype_digit($telegramId) ||
            $telegramId === '0'
        ) {
            return [
                'status' => 'invalid',
                'message' => 'Invalid Telegram account.'
            ];
        }

        if (
            !isset($contact['user_id']) ||
            (string)$contact['user_id'] !== $telegramId
        ) {
            return [
                'status' => 'invalid_contact',
                'message' => 'Please share your own phone number.'
            ];
        }

        try {
            $phone = $this->normalizePhone(
                $contact['phone_number'] ?? ''
            );
        } catch (InvalidArgumentException $e) {
            return [
                'status' => 'invalid_phone',
                'message' => 'The phone number format is invalid.'
            ];
        }

        $username = $telegramUser['username'] ?? null;

        if ($username !== null) {
            $username = trim($username);

            if (
                $username === '' ||
                !preg_match('/^[A-Za-z0-9_]{5,32}$/', $username)
            ) {
                return [
                    'status' => 'invalid_username',
                    'message' => 'Invalid Telegram username.'
                ];
            }
        }

        $firstName = trim($telegramUser['first_name'] ?? '');
        $lastName = trim($telegramUser['last_name'] ?? '');

        if ($firstName === '' || mb_strlen($firstName) > 255) {
            return [
                'status' => 'invalid_name',
                'message' => 'Your Telegram first name is invalid.'
            ];
        }

        if (mb_strlen($lastName) > 255) {
            return [
                'status' => 'invalid_name',
                'message' => 'Your last name is too long.'
            ];
        }

        try {
            // Check existing Telegram account.
            $stmt = $this->db->prepare(
                "SELECT * FROM users WHERE user_id = ? FOR UPDATE"
            );

            $stmt->execute([$telegramId]);
            $existing = $stmt->fetch();

            // Check phone ownership.
            $stmt = $this->db->prepare(
                "SELECT user_id FROM users WHERE phone_number = ?"
            );

            $stmt->execute([$phone]);
            $phoneOwner = $stmt->fetch();

            if (
                $phoneOwner &&
                (string)$phoneOwner['user_id'] !== $telegramId
            ) {
                return [
                    'status' => 'phone_exists',
                    'message' => 'This phone number is already registered to another account.'
                ];
            }

            // Check username ownership.
            if ($username !== null) {
                $stmt = $this->db->prepare(
                    "SELECT user_id FROM users WHERE user_name = ?"
                );

                $stmt->execute([$username]);
                $usernameOwner = $stmt->fetch();

                if (
                    $usernameOwner &&
                    (string)$usernameOwner['user_id'] !== $telegramId
                ) {
                    return [
                        'status' => 'username_exists',
                        'message' => 'This Telegram username is already registered to another account.'
                    ];
                }
            }

            // Existing user: update profile information.
            if ($existing) {

                if ($existing['phone_number'] !== $phone) {
                    return [
                        'status' => 'phone_changed',
                        'message' => 'Your account already exists with a different phone number. Please contact support to update it.'
                    ];
                }

                $stmt = $this->db->prepare(
                    "UPDATE users
                     SET user_name = ?,
                         first_name = ?,
                         last_name = ?
                     WHERE user_id = ?"
                );

                $stmt->execute([
                    $username,
                    $firstName,
                    $lastName !== '' ? $lastName : null,
                    $telegramId
                ]);

                return [
                    'status' => 'existing',
                    'message' => 'Welcome back! Your account is already registered.'
                ];
            }

            // Create new user.
            $stmt = $this->db->prepare(
                "INSERT INTO users
                (phone_number, user_id, user_name, first_name, last_name)
                VALUES (?, ?, ?, ?, ?)"
            );

            $stmt->execute([
                $phone,
                $telegramId,
                $username,
                $firstName,
                $lastName !== '' ? $lastName : null
            ]);

            return [
                'status' => 'created',
                'message' => 'Your account has been created successfully!'
            ];

        } catch (PDOException $e) {

            // Catch concurrent duplicate insertions.
            if ($e->getCode() === '23000') {
                return [
                    'status' => 'duplicate',
                    'message' => 'An account with these details already exists. Please try again or contact support.'
                ];
            }

            throw $e;
        }
    }
}
