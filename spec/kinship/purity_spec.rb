require "rails_helper"

# T1.9 — the engine must stay pure: no ActiveRecord/Rails/controller references
# anywhere under app/kinship. This is what keeps it exhaustively testable and
# portable to a future mobile implementation (docs/SPEC.md §2, §10).
RSpec.describe "Kinship engine purity" do
  engine_files = Rails.root.glob("app/kinship/**/*.rb")

  it "has engine files to inspect" do
    expect(engine_files).not_to be_empty
  end

  engine_files.each do |file|
    it "#{file.relative_path_from(Rails.root)} references no Rails/ActiveRecord constants" do
      # Inspect code only — comments are allowed to mention these names.
      code = file.read.lines.map { |line| line.sub(/#.*/, "") }.join
      expect(code).not_to match(/ActiveRecord|ApplicationRecord|ActionController|\bRails\./)
    end
  end
end
