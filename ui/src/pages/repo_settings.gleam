import components
import config.{type Config}
import gleam/int
import gleam/list
import gleam/option
import gleam/string
import http/api.{type Label, type Org, type Repo, type RepoDetail}
import http/lustre_http
import labels_ui
import lustre/attribute as attr
import lustre/effect.{type Effect}
import lustre/element.{type Element, memo, ref, text}
import lustre/element/html.{
  button, div, form, h3, input, li, option, p, select, span, textarea, ul,
}
import lustre/event
import modem
import pages/repo_nav
import routes

pub type Model {
  Model(
    org_slug: String,
    repo_name: String,
    org_role: option.Option(String),
    protected_branches: List(String),
    protected_input: String,
    saving_protected: Bool,
    rename_name: String,
    saved_name: String,
    description: String,
    saved_description: String,
    description_seed: Int,
    general_saving: Bool,
    default_branch: option.Option(String),
    branch_options: List(String),
    default_branch_selection: String,
    saving_default_branch: Bool,
    required_approvals: Int,
    saved_required_approvals: Int,
    required_approvals_selection: String,
    saving_required_approvals: Bool,
    confirm_delete: Bool,
    labels: List(Label),
    label_name: String,
    label_color: String,
    creating_label: Bool,
    editing_label_id: option.Option(String),
    editing_label_name: String,
    editing_label_color: String,
    saving_label: Bool,
    loading: Bool,
    error: option.Option(String),
  )
}

pub type Msg {
  OrgLoaded(Result(Org, lustre_http.HttpError))
  RepoDetailLoaded(Result(RepoDetail, lustre_http.HttpError))
  BranchesLoaded(Result(List(String), lustre_http.HttpError))
  DescriptionChanged(String)
  SaveGeneral
  GeneralSaved(Result(Repo, lustre_http.HttpError))
  DefaultBranchChanged(String)
  SaveDefaultBranch
  DefaultBranchSaved(Result(RepoDetail, lustre_http.HttpError))
  RequiredApprovalsChanged(String)
  SaveRequiredApprovals
  RequiredApprovalsSaved(Result(Nil, lustre_http.HttpError))
  ProtectedBranchesLoaded(Result(List(String), lustre_http.HttpError))
  ProtectedInputChanged(String)
  AddProtectedBranch
  RemoveProtectedBranch(String)
  ProtectedBranchesSaved(Result(List(String), lustre_http.HttpError))
  RenameNameChanged(String)
  RequestDelete
  CancelDelete
  ConfirmDelete
  Deleted(Result(Nil, lustre_http.HttpError))
  LabelsLoaded(Result(List(Label), lustre_http.HttpError))
  LabelNameChanged(String)
  LabelColorChanged(String)
  CreateLabel
  LabelCreated(Result(Label, lustre_http.HttpError))
  DeleteLabel(String)
  LabelDeleted(Result(Nil, lustre_http.HttpError))
  StartEditLabel(String, String, String)
  CancelEditLabel
  EditLabelNameChanged(String)
  EditLabelColorChanged(String)
  SaveLabel
  LabelUpdated(Result(Label, lustre_http.HttpError))
}

pub fn init(org_slug: String, repo_name: String) -> Model {
  Model(
    org_slug:,
    repo_name:,
    org_role: option.None,
    protected_branches: [],
    protected_input: "",
    saving_protected: False,
    rename_name: repo_name,
    saved_name: repo_name,
    description: "",
    saved_description: "",
    description_seed: 0,
    general_saving: False,
    default_branch: option.None,
    branch_options: [],
    default_branch_selection: "",
    saving_default_branch: False,
    required_approvals: 0,
    saved_required_approvals: 0,
    required_approvals_selection: "0",
    saving_required_approvals: False,
    confirm_delete: False,
    labels: [],
    label_name: "",
    label_color: labels_ui.default_label_color,
    creating_label: False,
    editing_label_id: option.None,
    editing_label_name: "",
    editing_label_color: "",
    saving_label: False,
    loading: True,
    error: option.None,
  )
}

pub fn on_load(config: Config, model: Model) -> Effect(Msg) {
  lustre_http.get(
    config,
    config.api_url <> "/api/orgs/" <> model.org_slug,
    lustre_http.expect_json(api.org_decoder(), OrgLoaded),
  )
}

fn api_base(config: Config, model: Model) -> String {
  config.api_url
  <> "/api/orgs/"
  <> model.org_slug
  <> "/repos/"
  <> model.repo_name
}

fn is_owner(model: Model) -> Bool {
  model.org_role == option.Some("owner")
}

fn load_repo_detail(config: Config, model: Model) -> Effect(Msg) {
  lustre_http.get(
    config,
    api_base(config, model),
    lustre_http.expect_json(api.repo_detail_decoder(), RepoDetailLoaded),
  )
}

fn load_branches(config: Config, model: Model) -> Effect(Msg) {
  lustre_http.get(
    config,
    api_base(config, model) <> "/branches",
    lustre_http.expect_json(api.branches_decoder(), BranchesLoaded),
  )
}

fn load_protected_branches(config: Config, model: Model) -> Effect(Msg) {
  lustre_http.get(
    config,
    api_base(config, model) <> "/protected-branches",
    lustre_http.expect_json(
      api.protected_branches_decoder(),
      ProtectedBranchesLoaded,
    ),
  )
}

fn load_labels(config: Config, model: Model) -> Effect(Msg) {
  lustre_http.get(
    config,
    api_base(config, model) <> "/labels",
    lustre_http.expect_json(api.labels_decoder(), LabelsLoaded),
  )
}

fn save_protected_branches(
  config: Config,
  model: Model,
  branches: List(String),
) -> Effect(Msg) {
  lustre_http.put(
    config,
    api_base(config, model) <> "/protected-branches",
    api.protected_branches_body(branches),
    lustre_http.expect_json(
      api.protected_branches_decoder(),
      ProtectedBranchesSaved,
    ),
  )
}

pub fn update(msg: Msg, model: Model, config: Config) -> #(Model, Effect(Msg)) {
  case msg {
    OrgLoaded(Ok(org)) -> #(
      Model(..model, org_role: org.role, loading: False),
      case org.role {
        option.Some("owner") ->
          effect.batch([
            load_repo_detail(config, model),
            load_branches(config, model),
            load_protected_branches(config, model),
            load_labels(config, model),
          ])
        _ -> effect.none()
      },
    )
    OrgLoaded(Error(_)) -> #(Model(..model, loading: False), effect.none())
    RepoDetailLoaded(Ok(detail)) -> {
      let description = case detail.description {
        option.Some(text) -> text
        option.None -> ""
      }
      #(
        Model(
          ..model,
          rename_name: detail.name,
          saved_name: detail.name,
          description:,
          saved_description: description,
          description_seed: model.description_seed + 1,
          default_branch: detail.default_branch,
          default_branch_selection: case detail.default_branch {
            option.Some(branch) -> branch
            option.None -> ""
          },
          required_approvals: detail.required_approvals,
          saved_required_approvals: detail.required_approvals,
          required_approvals_selection:
            int.to_string(detail.required_approvals),
        ),
        effect.none(),
      )
    }
    RepoDetailLoaded(Error(_)) -> #(model, effect.none())
    BranchesLoaded(Ok(branches)) -> #(
      Model(..model, branch_options: branches),
      effect.none(),
    )
    BranchesLoaded(Error(_)) -> #(model, effect.none())
    DescriptionChanged(value) -> #(
      Model(..model, description: value),
      effect.none(),
    )
    SaveGeneral -> {
      let name = string.trim(model.rename_name)
      let name_changed = name != model.saved_name
      let description_changed = model.description != model.saved_description
      case name_changed || description_changed {
        False -> #(model, effect.none())
        True -> #(
          Model(..model, general_saving: True, error: option.None),
          lustre_http.patch(
            config,
            api_base(config, model),
            api.update_repo_body(name, model.description),
            lustre_http.expect_json(api.repo_decoder(), GeneralSaved),
          ),
        )
      }
    }
    GeneralSaved(Ok(repo)) -> {
      let description = case repo.description {
        option.Some(text) -> text
        option.None -> ""
      }
      case repo.name != model.repo_name {
        True -> #(
          model,
          modem.replace(
            routes.repo_settings_path(model.org_slug, repo.name),
            option.None,
            option.None,
          ),
        )
        False -> #(
          Model(
            ..model,
            rename_name: repo.name,
            saved_name: repo.name,
            description:,
            saved_description: description,
            description_seed: model.description_seed + 1,
            general_saving: False,
            error: option.None,
          ),
          effect.none(),
        )
      }
    }
    GeneralSaved(Error(lustre_http.OtherError(403, _))) -> #(
      Model(
        ..model,
        general_saving: False,
        error: option.Some(
          "Only organization owners can change repository settings",
        ),
      ),
      effect.none(),
    )
    GeneralSaved(Error(lustre_http.OtherError(400, _))) -> #(
      Model(
        ..model,
        general_saving: False,
        error: option.Some("Invalid repository name or description"),
      ),
      effect.none(),
    )
    GeneralSaved(Error(lustre_http.OtherError(422, _))) -> #(
      Model(
        ..model,
        general_saving: False,
        error: option.Some("That repository name is already in use"),
      ),
      effect.none(),
    )
    GeneralSaved(Error(lustre_http.NotFound)) -> #(
      Model(
        ..model,
        general_saving: False,
        error: option.Some("Repository not found"),
      ),
      effect.none(),
    )
    GeneralSaved(Error(_)) -> #(
      Model(
        ..model,
        general_saving: False,
        error: option.Some("Could not save repository settings"),
      ),
      effect.none(),
    )
    DefaultBranchChanged(branch) -> #(
      Model(..model, default_branch_selection: branch),
      effect.none(),
    )
    SaveDefaultBranch -> {
      let branch = string.trim(model.default_branch_selection)
      case branch {
        "" -> #(model, effect.none())
        _ ->
          case model.default_branch == option.Some(branch) {
            True -> #(model, effect.none())
            False -> #(
              Model(..model, saving_default_branch: True, error: option.None),
              lustre_http.put(
                config,
                api_base(config, model) <> "/default-branch",
                api.default_branch_body(branch),
                lustre_http.expect_json(
                  api.repo_detail_decoder(),
                  DefaultBranchSaved,
                ),
              ),
            )
          }
      }
    }
    DefaultBranchSaved(Ok(detail)) -> #(
      Model(
        ..model,
        default_branch: detail.default_branch,
        default_branch_selection: case detail.default_branch {
          option.Some(branch) -> branch
          option.None -> model.default_branch_selection
        },
        saving_default_branch: False,
        error: option.None,
      ),
      effect.none(),
    )
    DefaultBranchSaved(Error(lustre_http.OtherError(403, _))) -> #(
      Model(
        ..model,
        saving_default_branch: False,
        error: option.Some(
          "Only organization owners can change the default branch",
        ),
      ),
      effect.none(),
    )
    DefaultBranchSaved(Error(lustre_http.OtherError(400, _))) -> #(
      Model(
        ..model,
        saving_default_branch: False,
        error: option.Some("That branch does not exist"),
      ),
      effect.none(),
    )
    DefaultBranchSaved(Error(_)) -> #(
      Model(
        ..model,
        saving_default_branch: False,
        error: option.Some("Could not update default branch"),
      ),
      effect.none(),
    )
    RequiredApprovalsChanged(value) -> #(
      Model(..model, required_approvals_selection: value),
      effect.none(),
    )
    SaveRequiredApprovals -> {
      case int.parse(model.required_approvals_selection) {
        Error(_) -> #(
          Model(..model, error: option.Some("Invalid approval count")),
          effect.none(),
        )
        Ok(count) ->
          case count == model.saved_required_approvals {
            True -> #(model, effect.none())
            False -> #(
              Model(..model, saving_required_approvals: True, error: option.None),
              lustre_http.patch(
                config,
                api_base(config, model),
                api.required_approvals_body(count),
                lustre_http.expect_anything(RequiredApprovalsSaved),
              ),
            )
          }
      }
    }
    RequiredApprovalsSaved(Ok(_)) -> {
      let count = case int.parse(model.required_approvals_selection) {
        Ok(n) -> n
        Error(_) -> model.saved_required_approvals
      }
      #(
        Model(
          ..model,
          required_approvals: count,
          saved_required_approvals: count,
          saving_required_approvals: False,
          error: option.None,
        ),
        effect.none(),
      )
    }
    RequiredApprovalsSaved(Error(lustre_http.OtherError(403, _))) -> #(
      Model(
        ..model,
        saving_required_approvals: False,
        error: option.Some(
          "Only organization owners can change merge settings",
        ),
      ),
      effect.none(),
    )
    RequiredApprovalsSaved(Error(lustre_http.OtherError(400, _))) -> #(
      Model(
        ..model,
        saving_required_approvals: False,
        error: option.Some("Invalid approval count"),
      ),
      effect.none(),
    )
    RequiredApprovalsSaved(Error(_)) -> #(
      Model(
        ..model,
        saving_required_approvals: False,
        error: option.Some("Could not save merge settings"),
      ),
      effect.none(),
    )
    ProtectedBranchesLoaded(Ok(branches)) -> #(
      Model(..model, protected_branches: branches),
      effect.none(),
    )
    ProtectedBranchesLoaded(Error(_)) -> #(model, effect.none())
    ProtectedInputChanged(value) -> #(
      Model(..model, protected_input: value),
      effect.none(),
    )
    AddProtectedBranch -> {
      let name = string.trim(model.protected_input)
      case name {
        "" -> #(model, effect.none())
        _ ->
          case list.contains(model.protected_branches, name) {
            True -> #(
              Model(..model, error: option.Some("Branch is already protected")),
              effect.none(),
            )
            False -> {
              let branches = list.append(model.protected_branches, [name])
              #(
                Model(
                  ..model,
                  protected_branches: branches,
                  protected_input: "",
                  saving_protected: True,
                  error: option.None,
                ),
                save_protected_branches(config, model, branches),
              )
            }
          }
      }
    }
    RemoveProtectedBranch(name) -> {
      let branches = list.filter(model.protected_branches, fn(b) { b != name })
      #(
        Model(..model, protected_branches: branches, saving_protected: True),
        save_protected_branches(config, model, branches),
      )
    }
    ProtectedBranchesSaved(Ok(branches)) -> #(
      Model(..model, protected_branches: branches, saving_protected: False),
      effect.none(),
    )
    ProtectedBranchesSaved(Error(lustre_http.OtherError(403, _))) -> #(
      Model(
        ..model,
        saving_protected: False,
        error: option.Some(
          "Only organization owners can change protected branches",
        ),
      ),
      effect.none(),
    )
    ProtectedBranchesSaved(Error(_)) -> #(
      Model(
        ..model,
        saving_protected: False,
        error: option.Some("Could not save protected branches"),
      ),
      effect.none(),
    )
    RenameNameChanged(name) -> #(
      Model(..model, rename_name: name),
      effect.none(),
    )
    RequestDelete -> #(
      Model(..model, confirm_delete: True, error: option.None),
      effect.none(),
    )
    CancelDelete -> #(Model(..model, confirm_delete: False), effect.none())
    ConfirmDelete -> #(
      Model(..model, confirm_delete: False),
      lustre_http.delete(
        config,
        api_base(config, model),
        lustre_http.expect_anything(Deleted),
      ),
    )
    Deleted(Ok(_)) -> #(
      model,
      modem.replace("/orgs/" <> model.org_slug, option.None, option.None),
    )
    Deleted(Error(lustre_http.OtherError(403, _))) -> #(
      Model(
        ..model,
        error: option.Some("Only organization owners can delete repositories"),
      ),
      effect.none(),
    )
    Deleted(Error(_)) -> #(
      Model(..model, error: option.Some("Could not delete repository")),
      effect.none(),
    )
    LabelsLoaded(Ok(labels)) -> #(Model(..model, labels:), effect.none())
    LabelsLoaded(Error(_)) -> #(model, effect.none())
    LabelNameChanged(name) -> #(Model(..model, label_name: name), effect.none())
    LabelColorChanged(color) -> #(
      Model(..model, label_color: color),
      effect.none(),
    )
    CreateLabel -> {
      let name = string.trim(model.label_name)
      case name {
        "" -> #(model, effect.none())
        _ -> #(
          Model(..model, creating_label: True, error: option.None),
          lustre_http.post(
            config,
            api_base(config, model) <> "/labels",
            api.create_label_body(name, model.label_color),
            lustre_http.expect_json(api.label_decoder(), LabelCreated),
          ),
        )
      }
    }
    LabelCreated(Ok(label)) -> #(
      Model(
        ..model,
        labels: list.append(model.labels, [label]),
        label_name: "",
        label_color: labels_ui.default_label_color,
        creating_label: False,
      ),
      effect.none(),
    )
    LabelCreated(Error(lustre_http.OtherError(400, _))) -> #(
      Model(
        ..model,
        creating_label: False,
        error: option.Some("Could not create label (invalid name or duplicate)"),
      ),
      effect.none(),
    )
    LabelCreated(Error(_)) -> #(
      Model(
        ..model,
        creating_label: False,
        error: option.Some("Could not create label"),
      ),
      effect.none(),
    )
    DeleteLabel(label_id) -> #(
      model,
      lustre_http.delete(
        config,
        api_base(config, model) <> "/labels/" <> label_id,
        lustre_http.expect_anything(LabelDeleted),
      ),
    )
    LabelDeleted(Ok(_)) -> #(model, load_labels(config, model))
    LabelDeleted(Error(_)) -> #(
      Model(..model, error: option.Some("Could not delete label")),
      effect.none(),
    )
    StartEditLabel(id, name, color) -> #(
      Model(
        ..model,
        editing_label_id: option.Some(id),
        editing_label_name: name,
        editing_label_color: color,
        error: option.None,
      ),
      effect.none(),
    )
    CancelEditLabel -> #(
      Model(
        ..model,
        editing_label_id: option.None,
        editing_label_name: "",
        editing_label_color: "",
      ),
      effect.none(),
    )
    EditLabelNameChanged(name) -> #(
      Model(..model, editing_label_name: name),
      effect.none(),
    )
    EditLabelColorChanged(color) -> #(
      Model(..model, editing_label_color: color),
      effect.none(),
    )
    SaveLabel -> {
      case model.editing_label_id {
        option.None -> #(model, effect.none())
        option.Some(label_id) -> #(
          Model(..model, saving_label: True, error: option.None),
          lustre_http.patch(
            config,
            api_base(config, model) <> "/labels/" <> label_id,
            api.update_label_body(
              option.Some(string.trim(model.editing_label_name)),
              option.Some(string.trim(model.editing_label_color)),
            ),
            lustre_http.expect_json(api.label_decoder(), LabelUpdated),
          ),
        )
      }
    }
    LabelUpdated(Ok(label)) -> #(
      Model(
        ..model,
        labels: list.map(model.labels, fn(existing) {
          case existing.id == label.id {
            True -> label
            False -> existing
          }
        }),
        editing_label_id: option.None,
        editing_label_name: "",
        editing_label_color: "",
        saving_label: False,
        error: option.None,
      ),
      effect.none(),
    )
    LabelUpdated(Error(lustre_http.OtherError(400, _))) -> #(
      Model(
        ..model,
        saving_label: False,
        error: option.Some("Could not update label (invalid name or duplicate)"),
      ),
      effect.none(),
    )
    LabelUpdated(Error(_)) -> #(
      Model(
        ..model,
        saving_label: False,
        error: option.Some("Could not update label"),
      ),
      effect.none(),
    )
  }
}

fn protected_branches_section(model: Model) -> Element(Msg) {
  div([attr.class(components.card <> " mb-6")], [
    h3([attr.class("mb-2 text-sm font-semibold text-gh-ink")], [
      text("Protected branches"),
    ]),
    p([attr.class("mb-3 text-sm text-gh-muted")], [
      text(
        "Direct pushes to these branches are blocked over SSH; use merge requests to update them.",
      ),
    ]),
    case model.protected_branches {
      [] -> text("")
      branches ->
        ul(
          [attr.class("mb-3 space-y-2")],
          list.map(branches, fn(branch) {
            li([attr.class("flex items-center justify-between gap-2 text-sm")], [
              span([attr.class("font-mono text-gh-ink")], [text(branch)]),
              button(
                [
                  attr.type_("button"),
                  attr.class(components.btn_secondary <> " !py-1 !text-xs"),
                  attr.disabled(model.saving_protected),
                  event.on_click(RemoveProtectedBranch(branch)),
                ],
                [text("Remove")],
              ),
            ])
          }),
        )
    },
    div([attr.class("flex flex-wrap gap-2")], [
      input([
        attr.type_("text"),
        attr.placeholder("Branch name"),
        attr.value(model.protected_input),
        attr.class(components.input <> " !max-w-xs"),
        event.on_input(ProtectedInputChanged),
      ]),
      button(
        [
          attr.type_("button"),
          attr.class(components.btn_primary),
          attr.disabled(model.saving_protected),
          event.on_click(AddProtectedBranch),
        ],
        [text("Add")],
      ),
    ]),
  ])
}

fn labels_section(model: Model) -> Element(Msg) {
  div([attr.class(components.card <> " mb-6")], [
    h3([attr.class("mb-2 text-sm font-semibold text-gh-ink")], [text("Labels")]),
    p([attr.class("mb-3 text-sm text-gh-muted")], [
      text(
        "Labels can be applied to issues and merge requests in this repository.",
      ),
    ]),
    case model.labels {
      [] -> text("")
      labels ->
        ul(
          [attr.class("mb-4 space-y-2")],
          list.map(labels, fn(label) {
            let editing = model.editing_label_id == option.Some(label.id)
            li(
              [attr.class("flex flex-wrap items-center justify-between gap-2")],
              [
                case editing {
                  True ->
                    form(
                      [
                        attr.class("flex w-full flex-wrap items-end gap-2"),
                        event.on_submit(fn(_) { SaveLabel }),
                      ],
                      [
                        div([], [
                          span(
                            [attr.class("mb-1 block text-xs text-gh-muted")],
                            [
                              text("Name"),
                            ],
                          ),
                          input([
                            attr.type_("text"),
                            attr.value(model.editing_label_name),
                            attr.class(components.input <> " !max-w-xs"),
                            event.on_input(EditLabelNameChanged),
                          ]),
                        ]),
                        div([], [
                          span(
                            [attr.class("mb-1 block text-xs text-gh-muted")],
                            [
                              text("Color"),
                            ],
                          ),
                          labels_ui.label_color_picker(
                            model.editing_label_color,
                            EditLabelColorChanged,
                          ),
                        ]),
                        button(
                          [
                            attr.type_("submit"),
                            attr.class(components.btn_primary),
                            attr.disabled(model.saving_label),
                          ],
                          [text("Save")],
                        ),
                        button(
                          [
                            attr.type_("button"),
                            attr.class(components.btn_secondary),
                            event.on_click(CancelEditLabel),
                          ],
                          [text("Cancel")],
                        ),
                      ],
                    )
                  False ->
                    div(
                      [
                        attr.class(
                          "flex w-full flex-wrap items-center justify-between gap-2",
                        ),
                      ],
                      [
                        labels_ui.label_badge(label),
                        div([attr.class("flex gap-2")], [
                          button(
                            [
                              attr.type_("button"),
                              attr.class(
                                components.btn_secondary
                                <> " !h-8 !px-2 text-xs",
                              ),
                              event.on_click(StartEditLabel(
                                label.id,
                                label.name,
                                label.color,
                              )),
                            ],
                            [text("Edit")],
                          ),
                          button(
                            [
                              attr.type_("button"),
                              attr.class(
                                components.btn_secondary
                                <> " !h-8 !px-2 text-xs",
                              ),
                              event.on_click(DeleteLabel(label.id)),
                            ],
                            [text("Remove")],
                          ),
                        ]),
                      ],
                    )
                },
              ],
            )
          }),
        )
    },
    form(
      [
        attr.class("flex flex-wrap gap-2"),
        event.on_submit(fn(_) { CreateLabel }),
      ],
      [
        input([
          attr.type_("text"),
          attr.placeholder("Label name"),
          attr.value(model.label_name),
          attr.class(components.input <> " !max-w-xs"),
          event.on_input(LabelNameChanged),
        ]),
        labels_ui.label_color_picker(model.label_color, LabelColorChanged),
        button(
          [
            attr.type_("submit"),
            attr.class(components.btn_primary),
            attr.disabled(model.creating_label),
          ],
          [text("Add label")],
        ),
      ],
    ),
  ])
}

fn description_textarea(model: Model) -> Element(Msg) {
  memo([ref(model.description_seed)], fn() {
    textarea(
      [
        attr.id("repo-description"),
        attr.class(components.textarea <> " !min-h-[5rem]"),
        event.on_input(DescriptionChanged),
      ],
      model.description,
    )
  })
}

fn general_settings_changed(model: Model) -> Bool {
  string.trim(model.rename_name) != model.saved_name
  || model.description != model.saved_description
}

fn general_settings(model: Model) -> Element(Msg) {
  let save_disabled = model.general_saving || !general_settings_changed(model)
  div([attr.class(components.card <> " mb-6")], [
    h3([attr.class("mb-2 text-sm font-semibold text-gh-ink")], [
      text("General"),
    ]),
    form([attr.class("space-y-3"), event.on_submit(fn(_) { SaveGeneral })], [
      div([], [
        components.field_label("repo-rename", "Repository name"),
        input([
          attr.id("repo-rename"),
          attr.class(components.input),
          attr.value(model.rename_name),
          attr.placeholder("my_app"),
          event.on_input(RenameNameChanged),
        ]),
      ]),
      div([], [
        components.field_label("repo-description", "Description"),
        description_textarea(model),
      ]),
      components.form_actions([
        button(
          [
            attr.class(components.btn_primary),
            attr.type_("submit"),
            attr.disabled(save_disabled),
          ],
          [
            text(case model.general_saving {
              True -> "Saving…"
              False -> "Save changes"
            }),
          ],
        ),
      ]),
    ]),
  ])
}

fn default_branch_section(model: Model) -> Element(Msg) {
  let current = case model.default_branch {
    option.Some(branch) -> branch
    option.None -> "—"
  }
  let save_disabled =
    model.saving_default_branch
    || model.default_branch == option.Some(model.default_branch_selection)
    || model.default_branch_selection == ""
  div([attr.class(components.card <> " mb-6")], [
    h3([attr.class("mb-2 text-sm font-semibold text-gh-ink")], [
      text("Default branch"),
    ]),
    p([attr.class("mb-3 text-sm text-gh-muted")], [
      text("Current default: "),
      span([attr.class("font-mono text-gh-ink")], [text(current)]),
    ]),
    p([attr.class("mb-3 text-sm text-gh-muted")], [
      text("Open merge requests targeting the old default are unaffected."),
    ]),
    case model.branch_options {
      [] ->
        p([attr.class("text-sm text-gh-muted")], [
          text("No branches found in this repository."),
        ])
      branches ->
        form(
          [
            attr.class("flex flex-wrap items-end gap-2"),
            event.on_submit(fn(_) { SaveDefaultBranch }),
          ],
          [
            div([], [
              components.field_label("default-branch", "Branch"),
              select(
                [
                  attr.id("default-branch"),
                  attr.class(components.input <> " !w-auto !min-w-[10rem]"),
                  event.on_change(DefaultBranchChanged),
                ],
                list.map(branches, fn(branch) {
                  option(
                    [
                      attr.value(branch),
                      attr.selected(model.default_branch_selection == branch),
                    ],
                    branch,
                  )
                }),
              ),
            ]),
            button(
              [
                attr.class(components.btn_primary),
                attr.type_("submit"),
                attr.disabled(save_disabled),
              ],
              [
                text(case model.saving_default_branch {
                  True -> "Saving…"
                  False -> "Update default branch"
                }),
              ],
            ),
          ],
        )
    },
  ])
}

fn required_approvals_section(model: Model) -> Element(Msg) {
  let options = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
  let save_disabled =
    model.saving_required_approvals
    || model.required_approvals_selection
      == int.to_string(model.saved_required_approvals)
  div([attr.class(components.card <> " mb-6")], [
    h3([attr.class("mb-2 text-sm font-semibold text-gh-ink")], [
      text("Required approvals"),
    ]),
    p([attr.class("mb-3 text-sm text-gh-muted")], [
      text(
        "Merge requests must receive this many approving reviews before they can be merged. Set to 0 to disable.",
      ),
    ]),
    form(
      [
        attr.class("flex flex-wrap items-end gap-2"),
        event.on_submit(fn(_) { SaveRequiredApprovals }),
      ],
      [
        div([], [
          components.field_label("required-approvals", "Approvals required"),
          select(
            [
              attr.id("required-approvals"),
              attr.class(components.input <> " !w-auto !min-w-[10rem]"),
              event.on_change(RequiredApprovalsChanged),
            ],
            list.map(options, fn(count) {
              let value = int.to_string(count)
              let label = case count {
                0 -> "None"
                1 -> "1 approval"
                _ -> value <> " approvals"
              }
              option(
                [
                  attr.value(value),
                  attr.selected(model.required_approvals_selection == value),
                ],
                label,
              )
            }),
          ),
        ]),
        button(
          [
            attr.class(components.btn_primary),
            attr.type_("submit"),
            attr.disabled(save_disabled),
          ],
          [
            text(case model.saving_required_approvals {
              True -> "Saving…"
              False -> "Save"
            }),
          ],
        ),
      ],
    ),
  ])
}

fn danger_zone(_model: Model) -> Element(Msg) {
  div([attr.class(components.card <> " mb-6")], [
    p([attr.class("mb-2 text-sm font-medium text-gh-ink")], [
      text("Danger zone"),
    ]),
    p([attr.class("mb-3 text-sm text-gh-muted")], [
      text("Permanently delete this repository and its git data on disk."),
    ]),
    button(
      [
        attr.class(components.btn_danger),
        attr.type_("button"),
        event.on_click(RequestDelete),
      ],
      [text("Delete repository")],
    ),
  ])
}

pub fn view(model: Model) -> Element(Msg) {
  let error = case model.error {
    option.Some(e) -> components.error_alert(e)
    option.None -> text("")
  }
  let confirm = case model.confirm_delete {
    True ->
      components.confirm_banner(
        "Delete repository?",
        "Permanently delete "
          <> model.repo_name
          <> " and its git data on disk? This cannot be undone.",
        ConfirmDelete,
        CancelDelete,
      )
    False -> text("")
  }
  let body = case model.loading {
    True -> components.loading_state()
    False ->
      case is_owner(model) {
        False ->
          components.empty_state(
            "Only organization owners can change repository settings.",
          )
        True ->
          div([], [
            general_settings(model),
            default_branch_section(model),
            required_approvals_section(model),
            labels_section(model),
            protected_branches_section(model),
            danger_zone(model),
          ])
      }
  }
  repo_nav.shell(model.org_slug, model.repo_name, repo_nav.Settings, [
    error,
    confirm,
    body,
  ])
}
