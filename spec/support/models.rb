# frozen_string_literal: true

# Tracks everything
class User < ActiveRecord::Base
  include Auditron::Auditable
  auditable
end

# Tracks only specific fields
class Post < ActiveRecord::Base
  include Auditron::Auditable
  auditable only: [:title]
end

# Actor model
class Admin < ActiveRecord::Base
end