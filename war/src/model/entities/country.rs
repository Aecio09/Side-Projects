#[derive(Clone)]
pub struct Country {
    pub name: &'static str,
    pub color: slint::Color,
    pub territories: i32,
    pub resources: i32,
    pub army: i32,
    pub initiative: u32,
    pub alive: bool,
}
