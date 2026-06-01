mod controller;
mod model;
mod view;

fn main() -> Result<(), slint::PlatformError> {
    controller::app::run()
}
