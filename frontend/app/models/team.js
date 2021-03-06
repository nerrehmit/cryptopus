import Model, { attr, hasMany } from "@ember-data/model";

export default class Team extends Model {
  @attr("string") name;
  @attr("string") description;
  @attr("boolean") private;
  @hasMany("folder") folders;
  @hasMany("teammember") teammembers;
}
