FactoryGirl.define do
  factory :user do
    sequence(:email) { |n| "user#{n}_#{rand(0..65535).to_s(16)}@example.com" }
    password 'password'

    factory :downloader do
      email 'downloader@example.com'
    end

    factory :depositor do
      email 'depositor@example.com'
    end

    factory :moderator do
      email 'moderator@example.com'
    end

    factory :admin do
      email 'admin@example.com'
      after(:create) do |u|
        admin_role = Role.find_or_create_by(name: "admin")
        admin_role.users << u
        admin_role.save
      end
    end

  end
end

