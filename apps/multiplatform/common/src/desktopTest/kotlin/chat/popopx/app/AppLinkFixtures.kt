package chat.popopx.app

internal const val BADGE_LINK_PREFIX = "popopxchat:/badge/code/"
internal const val BADGE_LINK = "${BADGE_LINK_PREFIX}SB0000000000000000000"
internal const val OTHER_BADGE_LINK = "${BADGE_LINK_PREFIX}SB1111111111111111111"

internal fun badgeLinkOfBytes(size: Int): String = BADGE_LINK_PREFIX + "A".repeat(size - BADGE_LINK_PREFIX.length)

internal const val SHORT_CONNECTION_LINK = "popopx:/a#lrdvu2d8A1GumSmoKb2krQmtKhWXq-tyGpHuM7aMwsw?h=smp6.popopx.im"
private const val ONE_TIME_LINK_PREFIX = "popopx:/invitation#/?v=2-7&smp=smp%3A%2F%2Fexample&e2e=v%3D2-3%26kem_key%3D"
// an sntrup761 public key is 1158 bytes, 1544 characters in base64url
private const val KEM_KEY_CHARACTERS = 1544

internal fun oneTimeLinkWithKemKey(): String = ONE_TIME_LINK_PREFIX + "A".repeat(KEM_KEY_CHARACTERS)
