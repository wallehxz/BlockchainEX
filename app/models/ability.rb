# https://github.com/CanCanCommunity/cancancan/wiki/Defining-Abilities
class Ability
  include CanCan::Ability

  def initialize(user)
    user ||= User.new
    if user.email.present?
      can :manage, :all
    else
      can :cannot, :all
    end
  end
end
