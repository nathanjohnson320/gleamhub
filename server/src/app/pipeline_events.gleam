import app/database
import app/json_api
import gleam/dict
import gleam/erlang/process
import gleam/json
import gleam/list
import gleam/otp/actor
import gleam/otp/supervision
import gleam/result

pub type Message {
  Subscribe(merge_request_id: String, subscriber: process.Subject(String))
  Unsubscribe(merge_request_id: String, subscriber: process.Subject(String))
  Publish(merge_request_id: String, payload: String)
}

type State {
  State(subscribers: dict.Dict(String, List(process.Subject(String))))
}

pub fn supervised(
  name: process.Name(Message),
) -> supervision.ChildSpecification(Nil) {
  supervision.worker(fn() { start(name) })
}

pub fn start(
  name: process.Name(Message),
) -> Result(actor.Started(Nil), actor.StartError) {
  actor.new(State(subscribers: dict.new()))
  |> actor.on_message(handle_message)
  |> actor.named(name)
  |> actor.start
  |> result.map(fn(started) { actor.Started(pid: started.pid, data: Nil) })
}

pub fn publish_run(
  name: process.Name(Message),
  run: database.PipelineRunRow,
) {
  let payload = json.to_string(json_api.pipeline_run_json(run))
  publish(name, run.merge_request_id, payload)
}

pub fn publish(
  name: process.Name(Message),
  merge_request_id: String,
  payload: String,
) {
  process.send(
    process.named_subject(name),
    Publish(merge_request_id:, payload:),
  )
}

pub fn subscribe(
  name: process.Name(Message),
  merge_request_id: String,
  subscriber: process.Subject(String),
) {
  process.send(
    process.named_subject(name),
    Subscribe(merge_request_id:, subscriber:),
  )
}

pub fn unsubscribe(
  name: process.Name(Message),
  merge_request_id: String,
  subscriber: process.Subject(String),
) {
  process.send(
    process.named_subject(name),
    Unsubscribe(merge_request_id:, subscriber:),
  )
}

fn subscribers_for(
  subscribers: dict.Dict(String, List(process.Subject(String))),
  merge_request_id: String,
) -> List(process.Subject(String)) {
  case dict.get(subscribers, merge_request_id) {
    Ok(subs) -> subs
    Error(_) -> []
  }
}

fn handle_message(state: State, message: Message) -> actor.Next(State, Message) {
  case message {
    Subscribe(merge_request_id:, subscriber:) -> {
      let subs = subscribers_for(state.subscribers, merge_request_id)
      actor.continue(State(
        subscribers: dict.insert(
          state.subscribers,
          merge_request_id,
          list.append(subs, [subscriber]),
        ),
      ))
    }
    Unsubscribe(merge_request_id:, subscriber:) -> {
      let subs =
        subscribers_for(state.subscribers, merge_request_id)
        |> list.filter(fn(s) { s != subscriber })
      actor.continue(State(
        subscribers: dict.insert(state.subscribers, merge_request_id, subs),
      ))
    }
    Publish(merge_request_id:, payload:) -> {
      subscribers_for(state.subscribers, merge_request_id)
      |> list.each(fn(subscriber) { process.send(subscriber, payload) })
      actor.continue(state)
    }
  }
}
