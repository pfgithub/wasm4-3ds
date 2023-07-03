pub const Buttons = packed struct {
    // fb: face buttons, dp: dpad, tr: triggers, n3: new 3ds only, cs: cstick, cp: cpad
    fb_a: bool,
    fb_b: bool,
    select: bool,
    start: bool,
    dp_right: bool,
    dp_left: bool,
    dp_up: bool,
    dp_down: bool,
    tr_r: bool,
    tr_l: bool,
    fb_x: bool,
    fb_y: bool,
    unused_0: u2,
    n3_tr_zl: bool,
    n3_tr_zr: bool,
    unused_touch: bool,
    unused_1: u3,
    n3_cs_right: bool,
    n3_cs_left: bool,
    n3_cs_up: bool,
    n3_cs_down: bool,
    cp_right: bool,
    cp_left: bool,
    cp_up: bool,
    cp_down: bool,

    pub fn right(btn: Buttons) bool {
        return btn.dp_right or btn.cp_right;
    }
    pub fn left(btn: Buttons) bool {
        return btn.dp_left or btn.cp_left;
    }
    pub fn up(btn: Buttons) bool {
        return btn.dp_up or btn.cp_up;
    }
    pub fn down(btn: Buttons) bool {
        return btn.dp_down or btn.cp_down;
    }
};

  KEY_A = BIT(0), ///< A
  KEY_B = BIT(1), ///< B
  KEY_SELECT = BIT(2), ///< Select
  KEY_START = BIT(3), ///< Start
  KEY_DRIGHT = BIT(4), ///< D-Pad Right
  KEY_DLEFT = BIT(5), ///< D-Pad Left
  KEY_DUP = BIT(6), ///< D-Pad Up
  KEY_DDOWN = BIT(7), ///< D-Pad Down
  KEY_R = BIT(8), ///< R
  KEY_L = BIT(9), ///< L
  KEY_X = BIT(10), ///< X
  KEY_Y = BIT(11), ///< Y
  KEY_ZL = BIT(14), ///< ZL (New 3DS only)
  KEY_ZR = BIT(15), ///< ZR (New 3DS only)
  KEY_TOUCH = BIT(20), ///< Touch (Not actually provided by HID)
  KEY_CSTICK_RIGHT = BIT(24), ///< C-Stick Right (New 3DS only)
  KEY_CSTICK_LEFT = BIT(25), ///< C-Stick Left (New 3DS only)
  KEY_CSTICK_UP = BIT(26), ///< C-Stick Up (New 3DS only)
  KEY_CSTICK_DOWN = BIT(27), ///< C-Stick Down (New 3DS only)
  KEY_CPAD_RIGHT = BIT(28), ///< Circle Pad Right
  KEY_CPAD_LEFT = BIT(29), ///< Circle Pad Left
  KEY_CPAD_UP = BIT(30), ///< Circle Pad Up
  KEY_CPAD_DOWN = BIT(31), ///< Circle Pad Down
