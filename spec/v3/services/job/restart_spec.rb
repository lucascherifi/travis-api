require 'spec_helper'

describe Travis::API::V3::Services::Job::Restart do
  let(:repo)  { Travis::API::V3::Models::Repository.where(owner_name: 'svenfuchs', name: 'minimal').first }
  let(:build) { repo.builds.first }
  let(:job)   { build.jobs.first }
  let(:sidekiq_payload) { JSON.load(Sidekiq::Client.last['args'].last.to_json) }
  let(:sidekiq_params)  { Sidekiq::Client.last['args'].last.deep_symbolize_keys }

  before do
    Travis::Features.stubs(:owner_active?).returns(true)
    @original_sidekiq = Sidekiq::Client
    Sidekiq.send(:remove_const, :Client) # to avoid a warning
    Sidekiq::Client = []
  end

  after do
    Sidekiq.send(:remove_const, :Client) # to avoid a warning
    Sidekiq::Client = @original_sidekiq
  end

  describe "not authenticated" do
    before  { post("/v3/job/#{job.id}/restart")      }
    example { expect(last_response.status).to be == 403 }
    example { expect(JSON.load(body)).to      be ==     {
      "@type"         => "error",
      "error_type"    => "login_required",
      "error_message" => "login required"
    }}
  end

  describe "missing build, authenticated" do
    let(:token)   { Travis::Api::App::AccessToken.create(user: repo.owner, app_id: 1) }
    let(:headers) {{ 'HTTP_AUTHORIZATION' => "token #{token}"                        }}
    before        { post("/v3/job/9999999999/restart", {}, headers)                 }

    example { expect(last_response.status).to be == 404 }
    example { expect(JSON.load(body)).to      be ==     {
      "@type"         => "error",
      "error_type"    => "not_found",
      "error_message" => "job not found (or insufficient access)",
      "resource_type" => "job"
    }}
  end

  describe "existing repository, no push access" do
    let(:token)   { Travis::Api::App::AccessToken.create(user: repo.owner, app_id: 1) }
    let(:headers) {{ 'HTTP_AUTHORIZATION' => "token #{token}"                        }}
    before        { post("/v3/job/#{job.id}/restart", {}, headers)                 }

    example { expect(last_response.status).to be == 403 }
    example { expect(JSON.load(body).to_s).to include(
      "@type",
      "error_type",
      "insufficient_access",
      "error_message",
      "operation requires restart access to job",
      "resource_type",
      "job",
      "permission",
      "restart")
    }
  end

  describe "private repository, no access" do
    let(:token)   { Travis::Api::App::AccessToken.create(user: repo.owner, app_id: 1) }
    let(:headers) {{ 'HTTP_AUTHORIZATION' => "token #{token}"                        }}
    before        { repo.update_attribute(:private, true)                             }
    before        { post("/v3/job/#{job.id}/restart", {}, headers)                 }
    after         { repo.update_attribute(:private, false)                            }

    example { expect(last_response.status).to be == 404 }
    example { expect(JSON.load(body)).to      be ==     {
      "@type"         => "error",
      "error_type"    => "not_found",
      "error_message" => "job not found (or insufficient access)",
      "resource_type" => "job"
    }}
  end

  describe "existing repository, push access, job not already running" do
    let(:params)  {{}}
    let(:token)   { Travis::Api::App::AccessToken.create(user: repo.owner, app_id: 1)                          }
    let(:headers) {{ 'HTTP_AUTHORIZATION' => "token #{token}"                                                 }}
    before        { Travis::API::V3::Models::Permission.create(repository: repo, user: repo.owner, push: true) }

    describe "canceled state" do
      before        { job.update_attribute(:state, "canceled")                                                }
      before        { post("/v3/job/#{job.id}/restart", params, headers)                                      }

      example { expect(last_response.status).to be == 202 }
      example { expect(JSON.load(body).to_s).to include(
        "@type",
        "pending",
        "job",
        "@href",
        "@representation",
        "minimal",
        "restart",
        "id",
        "state_change")
      }

      example { expect(sidekiq_payload).to be == {
        "id"     => "#{job.id}",
        "user_id"=> repo.owner_id,
        "source" => "api"}
      }

      example { expect(Sidekiq::Client.last['queue']).to be == 'job_restarts'                }
      example { expect(Sidekiq::Client.last['class']).to be == 'Travis::Sidekiq::JobRestart' }
    end
    describe "errored state" do
      before        { job.update_attribute(:state, "errored")                                                }
      before        { post("/v3/job/#{job.id}/restart", params, headers)                                      }

      example { expect(last_response.status).to be == 202 }
      example { expect(JSON.load(body).to_s).to include(
        "@type",
        "pending",
        "job",
        "@href",
        "@representation",
        "minimal",
        "restart",
        "id",
        "state_change")
      }

      example { expect(sidekiq_payload).to be == {
        "id"     => "#{job.id}",
        "user_id"=> repo.owner_id,
        "source" => "api"}
      }

      example { expect(Sidekiq::Client.last['queue']).to be == 'job_restarts'                }
      example { expect(Sidekiq::Client.last['class']).to be == 'Travis::Sidekiq::JobRestart' }
    end
    describe "failed state" do
      before        { job.update_attribute(:state, "failed")                                                }
      before        { post("/v3/job/#{job.id}/restart", params, headers)                                      }

      example { expect(last_response.status).to be == 202 }
      example { expect(JSON.load(body).to_s).to include(
        "@type",
        "pending",
        "job",
        "@href",
        "@representation",
        "minimal",
        "restart",
        "id",
        "state_change")
      }

      example { expect(sidekiq_payload).to be == {
        "id"     => "#{job.id}",
        "user_id"=> repo.owner_id,
        "source" => "api"}
      }

      example { expect(Sidekiq::Client.last['queue']).to be == 'job_restarts'                }
      example { expect(Sidekiq::Client.last['class']).to be == 'Travis::Sidekiq::JobRestart' }
    end
    describe "passed state" do
      before        { job.update_attribute(:state, "passed")                                                }
      before        { post("/v3/job/#{job.id}/restart", params, headers)                                      }

      example { expect(last_response.status).to be == 202 }
      example { expect(JSON.load(body).to_s).to include(
        "@type",
        "pending",
        "job",
        "@href",
        "@representation",
        "minimal",
        "restart",
        "id",
        "state_change")
      }

      example { expect(sidekiq_payload).to be == {
        "id"     => "#{job.id}",
        "user_id"=> repo.owner_id,
        "source" => "api"}
      }

      example { expect(Sidekiq::Client.last['queue']).to be == 'job_restarts'                }
      example { expect(Sidekiq::Client.last['class']).to be == 'Travis::Sidekiq::JobRestart' }
    end

    describe "setting id has no effect" do
      before        { post("/v3/job/#{job.id}/restart", params, headers)                     }
      let(:params) {{ id: 42 }}
      example { expect(sidekiq_payload).to be == {
        "id"     => "#{job.id}",
        "user_id"=> repo.owner_id,
        "source" => "api"}
      }
    end
  end

  describe "existing repository, push access, job already running" do
    let(:params)  {{}}
    let(:token)   { Travis::Api::App::AccessToken.create(user: repo.owner, app_id: 1)                          }
    let(:headers) {{ 'HTTP_AUTHORIZATION' => "token #{token}"                                                 }}
    before        { Travis::API::V3::Models::Permission.create(repository: repo, user: repo.owner, push: true) }

    describe "started state" do
      before        { job.update_attribute(:state, "started")                                                   }
      before        { post("/v3/job/#{job.id}/restart", params, headers)                                      }

      example { expect(last_response.status).to be == 409 }
      example { expect(JSON.load(body)).to      be ==     {
        "@type"         => "error",
        "error_type"    => "job_already_running",
        "error_message" => "job already running, cannot restart"
      }}
    end

    describe "queued state" do
      before        { job.update_attribute(:state, "queued")                                                   }
      before        { post("/v3/job/#{job.id}/restart", params, headers)                                     }

      example { expect(last_response.status).to be == 409 }
      example { expect(JSON.load(body)).to      be ==     {
        "@type"         => "error",
        "error_type"    => "job_already_running",
        "error_message" => "job already running, cannot restart"
      }}
    end

    describe "received state" do
      before        { job.update_attribute(:state, "received")                                                  }
      before        { post("/v3/job/#{job.id}/restart", params, headers)                                      }

      example { expect(last_response.status).to be == 409 }
      example { expect(JSON.load(body)).to      be ==     {
        "@type"         => "error",
        "error_type"    => "job_already_running",
        "error_message" => "job already running, cannot restart"
      }}
    end
  end

  #  TODO decided to discuss further with rkh as this use case doesn't really exist at the moment
  #  and 'fixing' the query requires modifying workers that v2 uses, thereby running the risk of breaking v2,
  #  and also because in 6 months or so travis-hub will be able to cancel builds without using travis-core at all.
  #
  # describe "existing repository, application with full access" do
  #   let(:app_name)   { 'travis-example'                                                           }
  #   let(:app_secret) { '12345678'                                                                 }
  #   let(:sign_opts)  { "a=#{app_name}"                                                            }
  #   let(:signature)  { OpenSSL::HMAC.hexdigest('sha256', app_secret, sign_opts)                   }
  #   let(:headers)    {{ 'HTTP_AUTHORIZATION' => "signature #{sign_opts}:#{signature}"            }}
  #   before { Travis.config.applications = { app_name => { full_access: true, secret: app_secret }}}
  #   before { post("/v3/job/#{job.id}/restart", params, headers)                                }
  #
  #   describe 'without setting user' do
  #     let(:params) {{}}
  #     example { expect(last_response.status).to be == 400 }
  #     example { expect(JSON.load(body)).to      be ==     {
  #       "@type"         => "error",
  #       "error_type"    => "wrong_params",
  #       "error_message" => "missing user"
  #     }}
  #   end
  #
  #   describe 'setting user' do
  #     let(:params) {{ user: { id: repo.owner.id } }}
  #     example { expect(last_response.status).to be == 202 }
  #     example { expect(sidekiq_payload).to be == {
  #       # repository: { id: repo.id, owner_name: 'svenfuchs', name: 'minimal' },
  #       # user:       { id: repo.owner.id },
  #       # message:    nil,
  #       # branch:     'master',
  #       # config:     {}
  #     }}
  #   end
  # end
end
