require "rails_helper"

# Golden vectors are the language-agnostic ground truth for the engine
# (spec/fixtures/kinship_vectors.json). Every relationship slice adds cases here;
# a future mobile implementation must pass the SAME file. See docs/SPEC.md §2.
RSpec.describe "Kinship golden vectors" do
  let(:graph) { KinshipFixture.graph }
  data = KinshipFixture.vectors_data
  dialect = data[:dialect].to_sym

  data[:cases].each do |c|
    it "from #{c[:viewer]}, #{c[:target]} is called #{c[:term]}" do
      result = Kinship.term(viewer: c[:viewer].to_sym, target: c[:target].to_sym,
                            graph: graph, dialect: dialect)
      expect(result).to eq(c[:term])
    end
  end
end
