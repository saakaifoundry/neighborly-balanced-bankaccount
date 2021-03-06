require 'spec_helper'

describe Neighborly::Balanced::Bankaccount::PaymentsController do
  routes { Neighborly::Balanced::Bankaccount::Engine.routes }

  let(:current_user) { double('User').as_null_object }

  let(:bank_account) do
    double('::Balanced::BankAccount', href: '/ABANK').as_null_object
  end

  let(:customer) do
    double('::Balanced::Customer',
           bank_accounts: [bank_account],
           href:           '/qwertyuiop').as_null_object
  end

  before do
    ::Balanced::Customer.stub(:find).and_return(customer)
    ::Balanced::Customer.stub(:new).and_return(customer)
    ::Balanced::BankAccount.stub(:find).and_return(bank_account)
    Neighborly::Balanced::Bankaccount::PaymentGenerator.any_instance.stub(:complete)
  end

  context 'authenticated' do
    before { sign_in FactoryGirl.create(:user) }

    describe 'get new' do
      it 'should use accounts controller new action' do
        expect_any_instance_of(
          Neighborly::Balanced::Bankaccount::AccountsController
        ).to receive(:new)
        get :new, contribution_id: 42
      end
    end

    describe 'POST create' do
      shared_examples_for '#create' do
        let(:payment) do
          double('Payment', status: :succeeded).as_null_object
        end
        let(:params) do
          {
            'payment' => {
              resource_id_name => resource.id.to_s,
              'use_bank'       => '/ABANK',
              'user'           => {}
            },
          }
        end
        let(:resource) { FactoryGirl.create(resource_class.to_s.underscore) }

        it 'should receive authenticate_user!' do
          expect(controller).to receive(:authenticate_user!)
          post :create, params
        end

        before do
          Neighborly::Balanced::Bankaccount::PaymentGenerator.
            any_instance.
            stub(:status).
            and_return(:succeeded)
        end

        it 'generates new payment with given params' do
          Neighborly::Balanced::Bankaccount::PaymentGenerator.should_receive(:new).
            with(customer, an_instance_of(resource_class), params['payment']).
            and_return(payment)
          post :create, params
        end

        it 'completes a payment of the resource' do
          Neighborly::Balanced::Bankaccount::PaymentGenerator.any_instance.should_receive(:complete)
          post :create, params
        end

        context 'with successul checkout' do
          it 'redirects to contribute page' do
            post :create, params
            expect(response).to redirect_to(resource_path)
          end
        end

        context 'with pending checkout status' do
          before do
            Neighborly::Balanced::Bankaccount::PaymentGenerator.
              any_instance.
              stub(:status).
              and_return(:pending)
          end

          it 'redirects to contribute page' do
            post :create, params
            expect(response).to redirect_to(resource_path)
          end
        end

        context 'with unsuccessul checkout' do
          before do
            Neighborly::Balanced::Bankaccount::PaymentGenerator.
              any_instance.
              stub(:status).
              and_return(:failed)
          end

          it 'redirects to resource edit page' do
            post :create, params
            expect(response).to redirect_to(edit_resource_path)
          end
        end

        describe 'insertion of bank account to a customer' do
          it 'should use accounts controller attach_bank_to_customer method' do
            expect_any_instance_of(
              Neighborly::Balanced::Bankaccount::AccountsController
            ).to receive(:attach_bank_to_customer)
            post :create, params
          end
        end

        describe 'update customer' do
          it 'update user attributes and balanced customer' do
            expect_any_instance_of(
              Neighborly::Balanced::Customer
            ).to receive(:update!)
            post :create, params
          end
        end
      end

      context 'when resource is Contribution' do
        let(:resource_class)     { Contribution }
        let(:resource_id_name)   { 'contribution_id' }
        let(:resource_path) do
          project_contribution_path(resource.project, resource)
        end
        let(:edit_resource_path) do
          edit_project_contribution_path(resource.project, resource)
        end

        it_should_behave_like '#create'
      end

      context 'when resource is Match' do
        let(:resource_class)     { Match }
        let(:resource_id_name)   { 'match_id' }
        let(:resource_path) do
          project_match_path(resource.project, resource)
        end
        let(:edit_resource_path) do
          edit_project_match_path(resource.project, resource)
        end

        it_should_behave_like '#create'
      end
    end
  end
end
