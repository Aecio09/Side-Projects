use crate::model::GameState;
use crate::view;
use slint::{ComponentHandle, ModelRc, SharedString, VecModel};
use std::rc::Rc;

pub fn run() -> Result<(), slint::PlatformError> {
    let app = view::AppWindow::new()?;
    let state = Rc::new(std::cell::RefCell::new(GameState::new()));

    let cell_model = Rc::new(VecModel::<view::CellData>::from(
        (0..25)
            .map(|i| view::build_cell_data(&state.borrow(), i))
            .collect::<Vec<_>>(),
    ));
    let order_model = Rc::new(VecModel::<SharedString>::from(vec![]));

    app.set_cells(ModelRc::from(cell_model.clone()));
    app.set_order_model(ModelRc::from(order_model.clone()));

    {
        let mut st = state.borrow_mut();
        view::update_order_model(&st, &order_model);
        view::update_texts(&app, &st);
    }
    app.set_upgrade_visible(false);
    app.set_upgrade_text(SharedString::from(""));

    let state_for_click = state.clone();
    let cell_model_for_click = cell_model.clone();
    let order_model_for_click = order_model.clone();
    let app_handle = app.as_weak();
    app.on_cell_clicked(move |index| {
        let Some(app) = app_handle.upgrade() else {
            return;
        };
        let mut should_schedule = false;
        let mut st = state_for_click.borrow_mut();
        let mut action_done = false;
        if st.check_winner().is_some() {
            return;
        }
        if !st.is_player_turn() || st.ai_running {
            st.selected = None;
            st.upgrade_target = None;
            app.set_upgrade_visible(false);
            view::refresh_cells(&st, &cell_model_for_click);
            view::update_texts(&app, &st);
            return;
        }

        let index = index as usize;
        if let Some(sel) = st.selected {
            if sel == index && st.cells[index].owner == st.player_index {
                st.selected = None;
                st.upgrade_target = None;
                app.set_upgrade_visible(false);
                view::refresh_cells(&st, &cell_model_for_click);
                view::update_texts(&app, &st);
                action_done = true;
            }

            if !action_done && st.adjacent_indices(sel).contains(&index) {
                let attack = if st.cells[index].owner == st.player_index {
                    st.move_troops(sel, index);
                    false
                } else {
                    st.try_attack(sel, index)
                };
                st.selected = None;
                st.upgrade_target = None;
                app.set_upgrade_visible(false);
                view::refresh_cells(&st, &cell_model_for_click);
                view::update_texts(&app, &st);
                if st.check_winner().is_some() {
                    action_done = true;
                }
                if attack {
                    view::play_attack_animation(&app, &st, sel, index);
                }
                st.next_turn();
                view::refresh_cells(&st, &cell_model_for_click);
                view::update_order_model(&st, &order_model_for_click);
                view::update_texts(&app, &st);
                should_schedule = true;
                action_done = true;
            }
        }

        if !action_done && st.cells[index].owner == st.player_index {
            st.selected = Some(index);
            st.upgrade_target = None;
            app.set_upgrade_visible(false);
            view::refresh_cells(&st, &cell_model_for_click);
            view::update_texts(&app, &st);
        }
        drop(st);
        if should_schedule {
            schedule_ai_sequence(
                state_for_click.clone(),
                app.as_weak(),
                cell_model_for_click.clone(),
                order_model_for_click.clone(),
            );
        }
    });

    let state_for_right = state.clone();
    let cell_model_for_right = cell_model.clone();
    let order_model_for_right = order_model.clone();
    let app_handle = app.as_weak();
    app.on_cell_right_clicked(move |index| {
        let Some(app) = app_handle.upgrade() else {
            return;
        };
        let mut st = state_for_right.borrow_mut();
        if !st.is_player_turn() || st.ai_running {
            return;
        }
        let index = index as usize;
        if st.cells[index].owner != st.player_index {
            return;
        }
        st.selected = None;
        st.upgrade_target = Some(index);
        let cell = &st.cells[index];
        let mut info = String::new();
        if cell.barracks {
            info.push_str("Quartel: construído. ");
        } else {
            info.push_str("Quartel: disponível. ");
        }
        if cell.factory {
            info.push_str("Fábrica: construída.");
        } else {
            info.push_str("Fábrica: disponível.");
        }
        app.set_upgrade_text(SharedString::from(info));
        app.set_upgrade_visible(true);
        view::refresh_cells(&st, &cell_model_for_right);
        view::update_order_model(&st, &order_model_for_right);
        view::update_texts(&app, &st);
    });

    let state_for_end = state.clone();
    let cell_model_for_end = cell_model.clone();
    let order_model_for_end = order_model.clone();
    let app_handle = app.as_weak();
    app.on_end_turn_clicked(move || {
        let Some(app) = app_handle.upgrade() else {
            return;
        };
        let mut should_schedule = false;
        let mut st = state_for_end.borrow_mut();
        if st.check_winner().is_some() {
            return;
        }
        if st.is_player_turn() && !st.ai_running {
            st.next_turn();
            app.set_upgrade_visible(false);
            view::refresh_cells(&st, &cell_model_for_end);
            view::update_order_model(&st, &order_model_for_end);
            view::update_texts(&app, &st);
            should_schedule = true;
        }
        drop(st);
        if should_schedule {
            schedule_ai_sequence(
                state_for_end.clone(),
                app.as_weak(),
                cell_model_for_end.clone(),
                order_model_for_end.clone(),
            );
        }
    });

    let state_for_upgrade = state.clone();
    let cell_model_for_upgrade = cell_model.clone();
    let order_model_for_upgrade = order_model.clone();
    let app_handle = app.as_weak();
    app.on_upgrade_barracks(move || {
        let Some(app) = app_handle.upgrade() else {
            return;
        };
        let mut st = state_for_upgrade.borrow_mut();
        let Some(target) = st.upgrade_target else {
            return;
        };
        if st.cells[target].owner != st.player_index {
            return;
        }
        if st.build_barracks(target) {
            app.set_upgrade_text(SharedString::from("Quartel construído. Fábrica disponível."));
        } else {
            app.set_upgrade_text(SharedString::from("Não foi possível construir o quartel."));
        }
        view::refresh_cells(&st, &cell_model_for_upgrade);
        view::update_order_model(&st, &order_model_for_upgrade);
        view::update_texts(&app, &st);
    });

    let state_for_upgrade = state.clone();
    let cell_model_for_upgrade = cell_model.clone();
    let order_model_for_upgrade = order_model.clone();
    let app_handle = app.as_weak();
    app.on_upgrade_factory(move || {
        let Some(app) = app_handle.upgrade() else {
            return;
        };
        let mut st = state_for_upgrade.borrow_mut();
        let Some(target) = st.upgrade_target else {
            return;
        };
        if st.cells[target].owner != st.player_index {
            return;
        }
        if st.build_factory(target) {
            app.set_upgrade_text(SharedString::from("Fábrica construída. Quartel disponível."));
        } else {
            app.set_upgrade_text(SharedString::from("Não foi possível construir a fábrica."));
        }
        view::refresh_cells(&st, &cell_model_for_upgrade);
        view::update_order_model(&st, &order_model_for_upgrade);
        view::update_texts(&app, &st);
    });

    let state_for_upgrade = state.clone();
    let app_handle = app.as_weak();
    app.on_close_upgrade(move || {
        let Some(app) = app_handle.upgrade() else {
            return;
        };
        let mut st = state_for_upgrade.borrow_mut();
        st.upgrade_target = None;
        app.set_upgrade_visible(false);
    });

    app.run()
}

fn schedule_ai_sequence(
    state: Rc<std::cell::RefCell<GameState>>,
    app_weak: slint::Weak<view::AppWindow>,
    cell_model: Rc<VecModel<view::CellData>>,
    order_model: Rc<VecModel<SharedString>>,
) {
    {
        let mut st = state.borrow_mut();
        if st.current_country_index() == Some(st.player_index) || st.check_winner().is_some() {
            return;
        }
        st.ai_running = true;
    }
    slint::Timer::single_shot(std::time::Duration::from_millis(1200), move || {
        let Some(app) = app_weak.upgrade() else {
            return;
        };
        let mut st = state.borrow_mut();
        if st.check_winner().is_some() {
            st.ai_running = false;
            view::update_texts(&app, &st);
            return;
        }
        let Some(current) = st.current_country_index() else {
            st.ai_running = false;
            view::update_texts(&app, &st);
            return;
        };
        if current == st.player_index {
            st.ai_running = false;
            view::update_texts(&app, &st);
            return;
        }

        let attack = st.ai_action(current);
        if let Some((from, to)) = attack {
            view::play_attack_animation(&app, &st, from, to);
        }
        st.next_turn();
        view::refresh_cells(&st, &cell_model);
        view::update_order_model(&st, &order_model);
        view::update_texts(&app, &st);

        if st.current_country_index() != Some(st.player_index) && st.check_winner().is_none() {
            drop(st);
            schedule_ai_sequence(state, app.as_weak(), cell_model, order_model);
        } else {
            st.ai_running = false;
        }
    });
}
